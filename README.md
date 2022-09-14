# fly-machines-proxy-demo
A demo of a globally distributed platform of low-latency, high-volume gameservers built on Fly Machines and the Fly-Replay Header

## Problem

When we pick a compute offering on which to build a platform, we effectively weigh a set of difficult tradeoffs:

### Content Delivery Network (CDN)

If I want to minimize latency for my users, I can leverage edge services from a CDN (e.g. [Cloudflare Workers](https://developers.cloudflare.com/workers/)) or a serverless deployment platform (e.g. [Netlify Edge Functions](https://www.netlify.com/products/#netlify-edge-functions)) that has dozens of points of presence

... but now I'm married to a specific vendor and its peculiar limitations, especially when it comes to storing data (e.g. [Cloudflare KV store](https://developers.cloudflare.com/workers/learning/how-kv-works/) is eventually consistent) and synchronizing state ([Cloudflare Durable Objects](https://developers.cloudflare.com/workers/learning/using-durable-objects/) are strongly consistent, but each one is isolated).

### Functions / Platform as a Service (FaaS / PaaS)

If I want to remain cloud vendor-agnostic, leverage varied storage options, and still limit operational overhead, I can look at serverless compute options for containers (e.g. [AWS Fargate](https://aws.amazon.com/fargate/)) and functions (e.g. [AWS Lambda](https://aws.amazon.com/lambda/))

... but now I'm far from my users and I'm trying to get isolated regions to communicate over an abstract network layer that fights me.

### Infrastructure as a Service (IaaS)

If I want to maximize performance per dollar and keep control over the network, I could run VMs from a public cloud provider (e.g. [AWS EC2](https://aws.amazon.com/ec2/)) or on dedicated hardware (e.g. [Vultr Cloud Instance](https://www.vultr.com/products/optimized-cloud-compute/))

... but now I can't scale down to zero because traditional VMs are too slow to boot on-demand. (also, multi-region networking remains hard).

### Application Delivery Network (ADN)

On paper, the release of [Fly Machines](https://fly.io/blog/fly-machines/) provides an interesting alternative that ignores the above trade-offs entirely:

* [Firecracker microVMs](https://fly.io/blog/sandboxing-and-workload-isolation/) provide great workload isolation and quick boot times.
* [Fly Machines](https://fly.io/docs/reference/machines/) offer an API to manually orchestrate VMs and the ability to scale down to zero.
* The [WireGuard-backed Anycast network](https://fly.io/blog/ipv6-wireguard-peering/) connect instances across regions on a mesh VLAN.
* The [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/) dynamically configures Fly's built-in proxy to route network requests.

This all seems a bit too good to be true, so **this project explores how well these claims hold in practice, and where sharp edges remain**. To avoid sloppy comparisons, we take two precautions: 

1. We run a workload with requirements for low-latency, high-volume concurrent interactions (e.g. a chat service, a game server, or the [replidraw](https://github.com/rocicorp/replidraw) Figma-like demo app).
2. We limit our infrastructure expertise to that of a fairly mediocre engineer, yours truly, without access to a team of talented SREs.

With stringent requirements for low-latency, high concurrency, and strong consistency, the obvious benchmark is likely built on top of a CDN's edge offerings, with something like [Cloudflare's Durable Objects](https://developers.cloudflare.com/workers/learning/using-durable-objects) to sync state across executions. In fact, their release announcement specifically called out these use cases as [best-in-class for a CDN's edge services](https://blog.cloudflare.com/introducing-workers-durable-objects/). Let's now see what an ADN-based alternative could look like.

## Fly-powered Demo

**TODO** Insert link to the live demo and call-to-action

**TODO** Insert animated gif of the lobby redirecting to an active gameserver where messages flow in

So what's happening here?

Our solution has two parts: 

* A `lobby` that lists available gameservers in various regions and lets users join them. 
* A `gameserver` that accepts connections from many concurrent users, each one getting their own websocket to send actions and get updates. 

The `gameserver` serializes and synchronizes everyone's inputs and displays the resulting authoritative state back to users in real-time. We share the same codebase for the `lobby` and `webserver` and deploy it in two ways: a regular stateless fly app available to the internet serves the lobby route, while a set of 3 fly machines are pre-created (i.e. with fixed instance ids) to act as gameservers. Machines are closed off from the public internet by default; all sessions will initially route to the regular fly app that acts solely as lobby.

**TODO** Insert simple Excalidraw architecture diagram showing 2 public lobbies and 3 "private" gameservers

Any web server, such as Caddy, Deno's integrated server, or anything would work here. We run [`Phoenix`](https://github.com/phoenixframework/phoenix) because LiveViews (real-time server-rendered pages) let us minimize the amount of frontend code we write to focus on the interesting bits. The `lobby` is a LiveView that lives at `/`. It doesn't keep track of the state and IPs of the gameservers; it only knows about their `instance` ids. Each `gameserver` is a LiveView running at `/gameserver/<instance>` where `instance` is the id of the Fly Machine that hosts it.

**TODO** Insert simple Excalidraw networking diagram showing requests heading to Fly's edge and being rerouted to the selected instance by Fly's proxy

When a user joins a gameserver from the lobby, they attempt to `GET` the page at `/gameserver/<instance>` and the lobby automatically inserts the "Fly-Replay Header" to seamlessly redirect the connection to that specific instance. We rely on the [`Plug`](https://github.com/elixir-plug/plug) library for consistently adding the header on calls to the `/gameserver/` route.

**TODO** Insert a "sequence diagram" showing the user first `GET`ting a regular static page, upgrading to a websocket-powered LiveView, then opening a second WebSocket to connect to a bidirectional Channel to share messages with all users.

Besides loading the page itself, all users connected to a given gameserver open a WebSocket to a [Channel](https://hexdocs.pm/phoenix/channels.html) (the default PubSub mechanism in Phoenix). The Channel lets each user posts their messages as well as receive updates from everyone else in return.

## Findings and Sharp Edges

For the most part, this was surprisingly straightforward:

* [vs CDN] Getting all users on a single shared VM buys us low-latency and high-volume updates, without having to rely on a quirky serverless storage service.
* [vs CDN & FaaS] Working with full VMs at the edge provides a lot of flexibility in terms of architecture, such as letting us run whatever runtime and library we're familiar with. 
* [vs CDN & FaaS] We were able to test our code locally and iterate quickly, without having to push it to a serverless infra each time.
* [vs FaaS & PaaS & IaaS] We didn't have to punch holes through firewalls and security groups to get regions to talk to each other. 
* [vs PaaS & IaaS] Relying on the Fly-Replay Header removed the need to run our own proxy or a service mesh.

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