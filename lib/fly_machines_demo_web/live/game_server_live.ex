defmodule FlyMachinesDemoWeb.GameServerLive do
  use FlyMachinesDemoWeb, :live_view

  alias FlyMachinesDemo.Message

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
    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:authorid, UUID.uuid4())
      |> assign(:author, MnemonicSlugs.generate_slug())

    socket = assign(socket, :messages, get_messages(socket.assigns))

    {:ok, socket}
  end

  def handle_event("update-author", %{"_target" => ["author"], "author" => author}, socket) do
    {:noreply, assign(socket, :author, author)}
  end

  def handle_event("post-message", %{"message" => message}, socket) do
    {:noreply, assign(socket, messages: post_message(socket.assigns, message))}
  end

  defp get_messages(assigns) do
    @messages
    |> Enum.map(fn message ->
      message
      |> Map.put(:author, assigns.author)
      |> Map.put(:authorid, assigns.authorid)
    end)
  end

  defp post_message(assigns, message) do
    message_struct = %Message{
      text: message,
      authorid: assigns.authorid,
      author: assigns.author,
      time: Timex.now()
    }

    [message_struct | assigns.messages]
    |> Enum.slice(0..19)
  end
end
