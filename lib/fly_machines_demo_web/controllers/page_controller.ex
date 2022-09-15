defmodule FlyMachinesDemoWeb.PageController do
  use FlyMachinesDemoWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
