# fly-machines-proxy-demo
A demo of Fly Machines that demonstrates redirecting traffic with the Fly-Replay Header to build a globally distributed platform that scales down to zero.

## Context

Tech companies routinely make absurdly difficult architecture tradeoffs across a handful of compute options:

If I want to minimize latency for my users, I can leverage edge services from a CDN (e.g. [Cloudflare Workers](https://developers.cloudflare.com/workers/)) or a serverless deployment platform (e.g. [Netlify Edge Functions](https://www.netlify.com/products/#netlify-edge-functions)) that has dozens of points of presence

... but now I'm married to a specific vendor and the peculiar limitations of its edge compute.

If I want to remain vendor-agnostic and still limit operational overhead, public cloud providers offer serverless compute options for containers (e.g. [AWS Fargate](https://aws.amazon.com/fargate/)) and functions (e.g. [AWS Lambda](https://aws.amazon.com/lambda/))

... but now I'm trying to get isolated regions to communicate over an abstract network layer.

If I want to maximize performance and keep control of the network, I could run VMs from a public cloud provider (e.g. [AWS EC2](https://aws.amazon.com/ec2/)) or on dedicated hardware (e.g. [Vultr Cloud Instance](https://www.vultr.com/products/optimized-cloud-compute/))

... but now I can't scale down to zero because VMs are too slow to boot on-demand. (also, multi-region networking remains hard)

On paper, the release of [Fly Machines](https://fly.io/blog/fly-machines/) provides an interesting alternative that ignores these trade-offs entirely:

* [Firecracker microVMs](https://fly.io/blog/sandboxing-and-workload-isolation/) provide great workload isolation and quick boot times.
* The [WireGuard-backed Anycast network](https://fly.io/blog/ipv6-wireguard-peering/) connect instances across regions on their own "virtual LAN".
* [Fly Machines](https://fly.io/docs/reference/machines/) offer an API to scale down stopped instances and save money. 
* The [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/) dynamically configures Fly's built-in proxy to route network requests.

This all seems a bit too good to be true. This project explores how well these claims hold in practice, and where sharp edges still remain. To avoid shortcuts, we take two precautions: 

1. we run a workload with requirements for low-latency, high-volume interactions to a shared instance (e.g. a game server or the [replidraw](https://github.com/rocicorp/replidraw) Figma-like demo app)
2. we limit our infrastructure know-how to that of a fairly mediocre engineer, yours truly.

## Design Goals

### For the demo workload

### For the compute and networking platform

## Potential Solutions

### With Cloudflare as Content Delivery Network (CDN)

### With Fly.io as Application Delivery Network (ADN)

## Sharp Edges

Everything listed in the announcement blog post for [Fly Machines](https://fly.io/blog/fly-machines/#how-fly-machines-will-frustrate-you-the-emotional-cost-of-simplicity), most notably that stopped machines aren't fully free.

## References

* Fly.io reference for [Machines](https://fly.io/docs/reference/machines/) and the [Fly-Replay Header](https://fly.io/docs/reference/fly-replay/)
* Fly.io app guide for [building a FaaS](https://fly.io/docs/app-guides/functions-with-machines/) on top of machines
* Cloudflare reference for [Workers](https://developers.cloudflare.com/workers/), [websockets](https://developers.cloudflare.com/workers/learning/using-websockets/) and [durable objects](https://developers.cloudflare.com/workers/learning/using-durable-objects/)
* [replidraw](https://github.com/rocicorp/replidraw), a demo app for replicache that simulates "a tiny Figma-like multiplayer graphics editor"