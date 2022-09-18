defmodule FlyMachinesDemoWeb.GameServerLive do
  use FlyMachinesDemoWeb, :live_view

  alias FlyMachinesDemo.Message

  require Logger

  @messages [
    %Message{
      text:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
      time: Timex.now()
    },
    %Message{
      text:
        "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
      time: Timex.now()
    },
    %Message{
      text:
        "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
      time: Timex.now()
    }
  ]

  def mount(%{"instance" => instance}, _session, socket) do
    topic = "gameserver:#{instance}"

    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:topic, topic)
      |> assign(:authorid, UUID.uuid4())
      |> assign(:author, MnemonicSlugs.generate_slug())

    socket = assign(socket, :messages, get_messages(socket.assigns))

    if connected?(socket), do: FlyMachinesDemoWeb.Endpoint.subscribe(topic)

    {:ok, socket}
  end

  def handle_event("update-author", %{"_target" => ["author"], "author" => author}, socket) do
    {:noreply, assign(socket, :author, author)}
  end

  def handle_event("post-message", %{"message" => message}, socket) do
    message_struct = format_own_message(socket.assigns, message)

    FlyMachinesDemoWeb.Endpoint.local_broadcast(
      socket.assigns.topic,
      "broadcast-message",
      message_struct
    )

    {:noreply, assign(socket, messages: post_message(socket.assigns, message_struct))}
  end

  def handle_info(
        %{event: "broadcast-message", payload: %Message{authorid: authorid}},
        socket
      )
      when authorid == socket.assigns.authorid,
      do: {:noreply, socket}

  def handle_info(
        %{event: "broadcast-message", payload: %Message{} = message_struct},
        socket
      ),
      do: {:noreply, assign(socket, messages: post_message(socket.assigns, message_struct))}

  defp get_messages(assigns) do
    @messages
    |> Enum.map(fn message ->
      message
      |> Map.put(:author, assigns.author)
      |> Map.put(:authorid, assigns.authorid)
    end)
  end

  defp format_own_message(assigns, message) do
    %Message{
      text: message,
      authorid: assigns.authorid,
      author: assigns.author,
      time: Timex.now()
    }
  end

  defp post_message(assigns, message_struct) do
    [message_struct | assigns.messages]
    |> Enum.slice(0..19)
  end
end
