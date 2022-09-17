defmodule FlyMachinesDemoWeb.LobbyLive do
  use FlyMachinesDemoWeb, :live_view

  def mount(_params, _session, socket) do
    # socket = assign(socket, key: value)
    {:ok, socket}
  end

end
