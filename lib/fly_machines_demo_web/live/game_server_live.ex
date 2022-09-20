defmodule FlyMachinesDemoWeb.GameServerLive do
  use FlyMachinesDemoWeb, :live_view

  alias FlyMachinesDemo.Message

  require Logger

  def mount(%{"instance" => instance}, _session, socket) do
    topic = "gameserver:#{instance}"

    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:topic, topic)
      |> assign(:authorid, UUID.uuid4())
      |> assign(:author, MnemonicSlugs.generate_slug())
      |> assign(:messages, get_welcome_messages())

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

  # Messages posted by the user are added to messages immediately for a better experience
  # In turn, they don't need to be added when they're broadcast back to the user
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

  defp get_welcome_messages() do
    [
      %Message{
        text: "Welcome to the chat!",
        time: Timex.now(),
        author: "admin"
      }
    ]
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
