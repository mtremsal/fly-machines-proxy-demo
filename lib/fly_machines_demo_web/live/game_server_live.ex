defmodule FlyMachinesDemoWeb.GameServerLive do
  use FlyMachinesDemoWeb, :live_view

  alias FlyMachinesDemo.Message

  @messages [
    %Message{
      text:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
    },
    %Message{
      text:
        "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
    },
    %Message{
      text:
        "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
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

  defp get_messages(assigns) do
    @messages
    |> Enum.map(fn message ->
      message
      |> Map.put(:author, assigns.author)
      |> Map.put(:authorid, assigns.authorid)
    end)
  end
end
