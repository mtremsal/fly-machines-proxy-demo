defmodule FlyMachinesDemoWeb.LobbyLive do
  use FlyMachinesDemoWeb, :live_view

  @instances ["nrt", "cdg", "ewr"]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:instances, @instances)
    {:ok, socket}
  end

end
