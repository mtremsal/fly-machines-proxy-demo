defmodule FlyMachinesDemoWeb.LobbyLive do
  use FlyMachinesDemoWeb, :live_view

  @instances ["abc-123", "def-456", "ghi-789"]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:instances, @instances)
    {:ok, socket}
  end

end
