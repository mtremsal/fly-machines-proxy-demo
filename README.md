# fly-machines-proxy-demo
A demo of Fly Machines that demonstrates redirecting traffic with the Fly-Replay Header to build a globally distributed platform that scales down to zero.

## Context

Tech companies routinely make absurdly difficult architecture tradeoffs across a handful of compute options:

### Content Delivery Network (CDN)

If I want to minimize latency for my users, I can leverage edge services from a CDN (e.g. [Cloudflare Workers](https://developers.cloudflare.com/workers/)) or a serverless deployment platform (e.g. [Netlify Edge Functions](https://www.netlify.com/products/#netlify-edge-functions)) that has dozens of points of presence

... but now I'm married to a specific vendor and its peculiar limitations, especially when it comes to storing data (e.g. [Cloudflare KV store](https://developers.cloudflare.com/workers/learning/how-kv-works/) is eventually consistent) and synchronizing state ([Cloudflare Durable Objects](https://developers.cloudflare.com/workers/learning/using-durable-objects/) are strongly consistent, but each one is isolated).

### Functions / Platform as a Service (FaaS / PaaS)

If I want to remain cloud vendor-agnostic, leverage varied storage options, and still limit operational overhead, I can consider serverless compute options for containers (e.g. [AWS Fargate](https://aws.amazon.com/fargate/)) and functions (e.g. [AWS Lambda](https://aws.amazon.com/lambda/))

... but now I'm far from my users and I'm trying to get isolated regions to communicate over an abstract network layer.

### Infrastructure as a Service (IaaS)

If I want to maximize performance and keep control of the network, I could run VMs from a public cloud provider (e.g. [AWS EC2](https://aws.amazon.com/ec2/)) or on dedicated hardware (e.g. [Vultr Cloud Instance](https://www.vultr.com/products/optimized-cloud-compute/))

... but now I can't scale down to zero because VMs are too slow to boot on-demand. (also, multi-region networking remains hard).

### Application Delivery Network (ADN)

On paper, the release of [Fly Machines](https://fly.io/blog/fly-machines/) provides an interesting alternative that ignores the above trade-offs entirely:

* [Firecracker microVMs](https://fly.io/blog/sandboxing-and-workload-isolation/) provide great workload isolation and quick boot times.
* [Fly Machines](https://fly.io/docs/reference/machines/) offer an API to scale down stopped instances and save money.
* The [WireGuard-backed Anycast network](https://fly.io/blog/ipv6-wireguard-peering/) connect instances across regions on a mesh VLAN.
* The [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/) dynamically configures Fly's built-in proxy to route network requests.

Frankly, this all seems a bit too good to be true. This project explores how well these claims hold in practice, and where sharp edges still remain. To avoid sloppy comparisons, we take two precautions: 

1. We run a stateful workload with requirements for low-latency, high-volume interactions (e.g. a game server or the [replidraw](https://github.com/rocicorp/replidraw) Figma-like demo app). This is precisely the kind of use case identified as [best-in-class for edge services](https://blog.cloudflare.com/introducing-workers-durable-objects/).
2. We limit our infrastructure expertise to that of a fairly mediocre engineer, yours truly, without access to a full team of SREs.

## Solution

Our solution has two parts:

* A `lobby` that lists available gameservers and lets users join them or start a new one in a predefined region.
* A `gameserver` that accepts connections from many concurrent users, each one getting their own websocket. The `gameserver` serializes and synchronizes everyone's inputs and displays back the resulting authoritative state in real-time.

We rely on Elixir [`Phoenix`](https://github.com/phoenixframework/phoenix) as a web server, with the following setup:

* The lobby page is a simple LiveView that lives at `/`. 
* Each gameserver is a static page running at `/game/<instance>` where `instance` is the instance id of the Fly Machine that hosts the game.
* The lobby doesn't keep track of the state and IPs of the gameservers. It only knows about their `instance` id.
* When a user joins a gameserver, they attempt to establish a websocket connection to the lobby that is seamlessly rerouted to a gameserver by adding the "Fly-Replay Header". We rely on the [`Plug`](https://github.com/elixir-plug/plug) library for adding the header when users reach the `/game/` route.
* We share the same codebase for the `lobby` and `webserver` and deploy it in two ways: a regular fly app available to the internet serves the lobby route, while a set of 3 fly machines (pre-created, with fixed instance ids) act as gameservers.

If at all possible, we take some precautions to keep the demo simple for non-Elixir folks:

* We don't leverage [Channels](https://hexdocs.pm/phoenix/channels.html) to avoid obfuscating how websockets work.
* We don't turn the `/game/` route into a LiveView to avoid the novel mechanism where the page first loads with a `GET` then upgrades to a websocket connection.

## Findings and Sharp Edges

For the most part, this was surprisingly straightforward to setup. In particular, working with full VMs at the edge provides a lot of flexibility in terms of architecture, such as letting me run whatever runtime and library I'm familiar with. We didn't have to punch holes through firewalls and security groups to get instances to talk to each other. Relying on the Fly-Replay Header removed the need to run my own proxy or a service mesh. Getting all users on a single gameserver to share a full VM really makes the demo sing.

While we didn't run into them, keep in mind the limitations listed in the announcement post for [Fly Machines](https://fly.io/blog/fly-machines/#how-fly-machines-will-frustrate-you-the-emotional-cost-of-simplicity), most notably that stopped machines aren't guaranteed to be available again and aren't fully free.

## Future improvements

The demo currently showcases a simple chat for the real-time collaboration use case. A quick improvement would be to upgrade to a real-time graphics editor or a multiplayer mini-game that would synchronize hundreds of updates per second for each user.

This demo doesn't currently demonstrate how machines scale to zero and boot fast. Ideally, unusued gameservers would shut down after n seconds. The lobby would list available regions (1 machine per region to keep things simple) rather than instance ids. The lobby would attempt to start a gameserver before a user joins it and cache the instance id locally. 

## References

* Fly.io reference for [Machines](https://fly.io/docs/reference/machines/) and the [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/)
* Fly.io app guide for [building a FaaS](https://fly.io/docs/app-guides/functions-with-machines/) on top of machines
* Cloudflare reference for [Workers](https://developers.cloudflare.com/workers/), [websockets](https://developers.cloudflare.com/workers/learning/using-websockets/) and [durable objects](https://developers.cloudflare.com/workers/learning/using-durable-objects/)
* [workers chat demo](https://github.com/cloudflare/workers-chat-demo), "written on Cloudflare Workers utilizing Durable Objects to implement real-time chat with stored history"
* [replidraw](https://github.com/rocicorp/replidraw), a demo app for replicache that simulates "a tiny Figma-like multiplayer graphics editor"