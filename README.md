# fly-machines-proxy-demo
A demo of a globally distributed platform of low-latency, high-volume gameservers built on Fly Machines and the Fly-Replay Header

[demo](https://fly-machines-proxy-demo.fly.dev) | [repo](https://github.com/mtremsal/fly-machines-proxy-demo)

## A Common Problem

There's a class of use cases that share similar requirements despite looking quite different at first glance:

* A chat room linearizes and displays concurrent messages between tens of thousands of users.
* A gameserver computes an authoritative state from the inputs of players and the internal logic of its world.
* A collaborative graphics editor syncs high-frequency changes to the positions, colors, etc. of its shapes.

In all cases:

1. **Low-latency** for users anywhere in the world is essential to a compelling user experience, implying a deployment across tens of regions. 
2. **Performant and scalable** compute is needed to process a high volume of concurrent inputs.
3. The service requires **strong consistency** to resolve inputs into a single source of truth before displaying it back to users.

Historically, these requirements have often resulted in difficult tradeoffs: _global, performant, strongly consistent -- pick 2_.

A potential approach could be to build such a service on top of a CDN's edge offerings. Maybe something like [Cloudflare Workers](https://developers.cloudflare.com/workers/) for globally distributed compute, connections over [WebSockets](https://developers.cloudflare.com/workers/runtime-apis/websockets/) for real-time low-latency communications, and updating [Durable Objects](https://developers.cloudflare.com/workers/learning/using-durable-objects) to sync state across parallel executions. In fact, the [release announcement](https://blog.cloudflare.com/introducing-workers-durable-objects/) for durable objects specifically calls similar use cases as their intended target.

Still, for an average engineer such as yours truly, this isn't exactly a walk in the park. We have to learn the specific APIs and idiosyncrasies of a given vendor. We can't easily test our code locally because a lot of the complexity comes from the interplay of various serverless offerings. We're strongly nudged towards the javascript / typescript / Wasm ecosystem rather than our runtime or framework of choice.

On paper, the release of [Fly Machines](https://fly.io/blog/fly-machines/) provides an interesting alternative:

* [Firecracker microVMs](https://fly.io/blog/sandboxing-and-workload-isolation/) provide great workload isolation, quick boot times, and performant compute.
* [Fly Machines](https://fly.io/docs/reference/machines/) offer an API to manually orchestrate VMs and the ability to scale down to zero.
* The [WireGuard-backed Anycast network](https://fly.io/blog/ipv6-wireguard-peering/) connect all instances across regions on a mesh VLAN.
* The [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/) dynamically configures Fly's built-in proxy to route network requests.

This all seems a bit too good to be true, so **this project explores how well these claims hold in practice, and where sharp edges remain**.

## Fly-powered Demo

**Try the demo at:** [fly-machines-proxy-demo.fly.dev](https://fly-machines-proxy-demo.fly.dev)

### Building a demo app

![demo1](./docs/assets/20220921_demo_1.gif)

Our solution has two parts: 

* A `lobby` that lists available gameservers in various regions and lets users join them. 
* A `gameserver` that accepts connections from many concurrent users. Each `gameserver` is in its own region, and only users connected to the same `gameserver` can chat together.

The `gameserver` serializes and synchronizes everyone's inputs and displays the resulting authoritative state back to users in real-time. We share the same codebase for the `lobby` and `webserver` and deploy it as a regular Fly App to n regions. Here, we've deployed to EWR (🇺🇸), NRT (🇯🇵), and CDG (🇫🇷). 

![regions](./docs/assets/20220921_drawing_1.png)

We could route traffic to individual instances, but to keep the demo simple, we're deploying 1 instance per region, and routing traffic per region. If we wanted to route traffic to individual instances, we'd need the instance ids to be static, which would also require deploying them as Fly Machines rather than a managed App.

We run the [`Phoenix`](https://github.com/phoenixframework/phoenix) web server because LiveViews (real-time server-rendered pages) let us minimize the amount of code we write for the frontend and PubSub mechanism, to focus on the interesting bits. The `lobby` is a LiveView that lives at `/`. The `gameserver` is a LiveView running at `/gameserver/<region>`. An individual instance doesn't keep track of which other instances are running, only that the app is deployed in 3 specific regions. 

The little flag shown in the navigation bar visually confirms where a request is served from based on the `FLY_REGION` env variable that each instance has access to. For now, we're serving all requests from the instance closest to the user, courtesy of Fly's Anycast network.

![liveview](./docs/assets/20220921_drawing_2.png)

When a user loads a LiveView, in practice it first GETs a static version of the HTML, then it establishes a websocket to open a stateful bidirectional connection that allows fast server-side rendering and dynamic updates. Rather than relying on traditional forms, we tap the websocket to post new messages, change the username, and refresh all messages in real time. We even piggyback on the websocket to subscribe to a shared PubSub topic called `gameserver:<region>`; each user broadcasts their own messages to the topic and receives everyone's messages in return. Phoenix and LiveView buy us quite a bit here: no SPA, no kafka, no refresh mechanism, etc.

Now time, to try and get `gameserver/cdg` to serve from the instance in the CDG region, and so on.

### Routing requests - the goal

There are a couple moving pieces to understand how one might go about "dynamically redirecting websockets".

The default behavior of Fly Apps is to route requests to the instance closest to the user. This is done by automatically assigning a single public-facing IPv4 address for the entire app, and when requests come in utilizing BGP Anycast to proxy the request where it has the least travel to do. It's pretty magical, and we definitely want to retain this behavior for serving the lobby (i.e. the `/` route).

Each instance also runs a [proxy](https://fly.io/docs/reference/architecture/#fly-networking) that, among other things, takes care of establishing the wireguard-based mesh connections to everything else that runs in your organization, essentially faking a local LAN despite everything being scattered across a bunch of different regions. This proxy is user-configurable to some extent with the [Fly Replay Header](https://fly.io/docs/reference/fly-replay/). By setting the `fly-replay` response header into HTTP calls we can tell the proxy _"while this was delivered to me, I'd like you to replay it to a different region/instance/app/etc. instead"_. So now, instead of deploying our own proxy or service mesh, and having to keep track of the IPs of our instances in a bunch of different regions, we can just declaratively say _"route this request over there, as if I had never received it in the first place"_. Pretty cool.

We'll want to avoid creating redirection loops. Let's say we inject `fly-replay region=cdg` in all calls to the `/gameserver/cdg` route. The first request reaches EWR (or whatever's closest) and the proxy agrees to replay it to CDG instead. But now we have a call to `/gameserver/cdg` that needs to actually be served by the instance in CDG. How do we insure we don't inject the response header into this call as well and cause a loop? Luckily for us, Fly's proxy adds a request header called `fly-replay-src` into all requests it replays. We just need to ensure we only inject the `fly-replay` response header into calls that don't already have `fly-replay-src` as a request header. (note: with this approach we're still doing a single pointless redirection if the user happens to initially be routed to the intended region because it's closest -- it's a local redirect taking 2ms so we can live with this.)

Okay, so our neat trick works for regular HTTP calls, but what about websockets? Crucially, establishing a websocket is really just going through a handshake with regular HTTP/1.1 calls. The client [opens the handshake](https://www.rfc-editor.org/rfc/rfc6455#section-1.3) by embedding the request headers `Upgrade: websocket` and `Connection: Upgrade`, and assuming the server agrees, it responds with a `101 Switching Protocols` response code. This looks a lot like the [TLS upgrade scheme](https://www.rfc-editor.org/rfc/rfc2817) (RFC2817). 

So, in theory, we can configure Fly's proxy to dynamically route regular requests as well as websockets to any region. For a LiveView, it would look like this:

![replay-header](./docs/assets/20220921_drawing_3.png)

Well, let's try to actually implement this, shall we?

### Routing requests - within Phoenix

Phoenix and its ecosystem rely on a library called `Plug` to model and modify connections. Plugs form "pipelines" that take successive actions on connections as they flow from the application's overall `Endpoint` to a `Router` and from there to a `Controller` or `LiveView`.

Here's our custom `Plug`:

```elixir
defmodule FlyMachinesDemoWeb.Plugs.FlyReplayHeader do
  alias Plug.Conn

  # The init function helps define compile-time options that define the behavior of the Plug.
  # Here we don't need to do anything, so we just return options
  def init(opts), do: opts

  # We pattern-match requests based on their path.
  # If they're directed at the /gameserver/<region> route, we consider replaying them elsewhere.
  def call(%Conn{path_info: ["gameserver" | path_info_tail]} = conn, _opts) do
    # Get the region from the second part of the path
    # We could do this with pattern-matching but it's not terribly easy to read.
    region = hd(path_info_tail) 
    
    # Is already replayed by proxy? If so, don't replay to avoid loops.
    # Otherwise, insert the "fly-replay" response header.
    if [] != Conn.get_req_header(conn, "fly-replay-src") do
      conn
    else
      Conn.put_resp_header(conn, "fly-replay", "region=#{region}")
    end
  end

  # Let all other requests flow through the Plug unchanged.
  def call(%Conn{} = conn, _opts), do: conn
end
```

Unfortunately, this approach doesn't fully work. Blink and you might miss it: the flag turns to NRT (🇯🇵) briefly then back to EWR (🇺🇸). While the initial static call gets redirected to the NRT region as expected, the LiveView's websocket handshake doesn't. Why is that?

![demo2](./docs/assets/20220921_demo_2.gif)

See [this thread](https://elixirforum.com/t/how-to-intercept-http-messages-generated-by-endpoints-socket-macro-with-a-plug/50377) for details. While nearly all steps in our connection plumbing (`Endpoint > Router > Controller`) are made of successive `Plug`s, mounting the websocket is handled slightly differently. The details are in the docs for [`Phoenix.Endpoint`](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3) and specifically the `socket` macro. The macro captures the websocket HTTP handshake, and thus doesn't let our custom `Plug` act on it downstream.

The lesson here is to pick a framework that lets you customize calls within the handshake to insert response headers. Node's `socket.io` should be able to handle this for example. But we're getting a log from Phoenix here, so let's deactivate our custom Plug and try to handle the routing logic outside of Phoenix. Let's partner with Caddy. 

![caddy](./docs/assets/golf_caddy.gif)

### Routing requests - with Caddy as reverse proxy

Caddy is a turnkey web server and reverse proxy written in go. It's quite beloved and full-featured, including for its default behavior of [using HTTPS automatically](https://caddyserver.com/docs/automatic-https#automatic-https). Nginx would definitely do the job, but Caddy's configuration file, the well-named `Caddyfile`, tends to be significantly more readable than its Nginx counterpart.

There are a couple interesting gotchas to deploying a reverse proxy on Fly, documented in this [other repo](https://github.com/mtremsal/fly-replay-header-caddy). But by and large, we're just deploying a regular Fly App from a Dockerfile with a simple config. The interesting bits are how to leverage Caddy's named matcher along with the `Map` and `Header` directives to handle the redirection. 

```Caddyfile
:8080 {
    # Parses the path to assign the variable {target_region} based on the second capture group of the regex
    map {path}                  {target_region} {
        ~(.*)/gameserver/(.*)$  "region=${2}"
        default                 ""
    }

    # Defines a named matcher that checks that the request is for a gameserver and hasn't been already redirected by the proxy
    @tobereplayed {
        path /gameserver/*
        header !fly-replay-src
    }

    # Adds a response header to all requests that should be replayed with the target region
    header @tobereplayed fly-replay {target_region}

    # Proxies everything to the upstream server (i.e. the demo app)
    reverse_proxy * https://fly-machines-proxy-demo.fly.dev:443
}
```

Surely this works, right? Close, but no cigar. 

Caddy's debug logs explain our mistake: we're not redirecting the handshake because it uses a static URI: `/live/websocket`. Unfortunately, simply adding this path to our `@tobereplayed` named matcher won't work, because we don't know where to replay the request. Not only the target region is not in the path, it's not anywhere to be seen in the HTTP request. 

If we hardcode the target instance in the Caddyfile, the full behavior works as expected. Huzzah! But of course, that's not quite as nice as our stated goal. Let's go back to Phoenix and figure out how to provide the target region somewhere in the websocket handshake!

![churchill](./docs/assets/darkest_hour.gif)

### Routing requests - with Caddy as reverse proxy and websocket params in Phoenix

We need to track which region the `/live/websocket` calls are meant to reach. There are two ways to achieve this: we can either store the target region in the session and inject it into the socket's [params](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-path-params),or we can add each region as a subdomain instead of in the path (e.g. `ewr.fly-replay-header-demo.fly.dev/gameserver`).

**TODO** Implement the subdomain routing, which is a common pattern for SaaS products

## Findings and Sharp Edges

**TODO** Summarize learnings, both the benefits of the approach, and the sharp edges to keep in mind when architecting for it.

* Getting all users on a single shared VM buys us low-latency and high-volume updates, without having to rely on a quirky serverless storage service.
* Working with full VMs at the edge provides a lot of flexibility in terms of architecture, such as letting us run whatever runtime and library we're familiar with. 
* ~~We were able to test our code locally and iterate quickly, without having to push it to several serverless APIs each time.~~ update: except for the networking part, which is unique de Fly
* ~~Relying on the Fly-Replay Header removed the need to run our own proxy or a service mesh, though to be fair, that's also not needed with serverless offerings.~~
* Compared to a traditional public cloud provider, we didn't have to punch holes through firewalls and security groups to get isolated regions to talk to each other. 

While we didn't run into them, let's keep in mind the limitations listed in the announcement post for [Fly Machines](https://fly.io/blog/fly-machines/#how-fly-machines-will-frustrate-you-the-emotional-cost-of-simplicity), most notably that stopped machines aren't guaranteed to be available again and aren't fully free.

## What's Next?

### Higher Throughput

The demo currently showcases a simple chat for the real-time collaboration use case. In particular, the chat use case is stateless: while there's a shared Channel for all connected users, each LiveView is in charge of displaying new messages that it receives. A quick improvement would be to have a stateful server that caches the last 100 messages received from the Channel so that new users can catch up on the conversation. A more involved upgrade would be to switch to a real-time graphics editor or a multiplayer mini-game that would synchronize hundreds of updates per second for each user.

### Network Isolation

While Machines are private by default, the demo still operates lobbies and gameservers on the same default network shared by the entire Fly organization. This is very convenient, but for a production scenario we'd likely isolate gameservers in their own private network. The guide to [build a Function-as-a-Service platform](https://fly.io/docs/app-guides/functions-with-machines/) touches on this point.

### VM Orchestration

The demo doesn't currently demonstrate how Machines scale to zero and boot fast. In fact, everything that we're currently doing could be achieved with a regular Fly app, without manually provisioning low-level Machines. A simple improvement would be to shut down empty gameservers (without any active websocket connection) after a few seconds. The lobby would list available regions (1 machine per region) rather than instance ids. It would start a gameserver before the first user joins it and cache its instance id locally. Note that the lobby remains stateless: if we attempt to start an already running gameserver, we can just ignore the error, cache its instance id, and move on.

## References

**[Fly.io docs and guides]** Reference for [Machines](https://fly.io/docs/reference/machines/) and the [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/). Guide for [building a FaaS](https://fly.io/docs/app-guides/functions-with-machines/) on top of machines.

**[Cloudflare docs and guides]** Reference for [Workers](https://developers.cloudflare.com/workers/), [websockets](https://developers.cloudflare.com/workers/learning/using-websockets/) and [durable objects](https://developers.cloudflare.com/workers/learning/using-durable-objects/).

**[Relevant demo apps]** [Workers chat demo](https://github.com/cloudflare/workers-chat-demo), "written on Cloudflare Workers utilizing Durable Objects to implement real-time chat with stored history". [Replidraw](https://github.com/rocicorp/replidraw), a demo app for Replicache that simulates "a tiny Figma-like multiplayer graphics editor".