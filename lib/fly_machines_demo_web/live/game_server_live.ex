defmodule FlyMachinesDemoWeb.GameServerLive do
  use FlyMachinesDemoWeb, :live_view

  @messages [
    %{text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
      author: "Alice",
      time: "1 min ago"},
      %{text: "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
      author: "Bob",
      time: "1 min ago"},
      %{text: "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
      author: "Charlie",
      time: "1 min ago"}
  ]

  def mount(%{"instance" => instance}, _session, socket) do
    socket =
      socket
      |> assign(:instance, instance)
      |> assign(:messages, @messages)
    {:ok, socket}
  end
end
