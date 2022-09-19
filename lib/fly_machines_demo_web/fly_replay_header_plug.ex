defmodule FlyMachinesDemoWeb.Plugs.FlyReplayHeader do
  alias Plug.Conn

  require Logger

  def init(opts), do: opts

  # Don't update requests for static assets
  # def call(%Conn{path_info: ["assets" | _path_info_tail]} = conn, _opts), do: conn
  # def call(%Conn{path_info: ["images" | _path_info_tail]} = conn, _opts), do: conn

  # Don't update requests for dev-only live_reload
  # def call(%Conn{path_info: ["phoenix", "live_reload", "frame"]} = conn, _opts), do: conn

  # Replay requests to /gameserver
  def call(%Conn{path_info: ["gameserver" | path_info_tail]} = conn, _opts) do
    region = hd(path_info_tail)
    replay(conn, region)
  end

  # Analyze all requests that aren't either static assets or /gameserver
  def call(%Conn{} = conn, _opts) do
    # Logger.info("This conn bypassed FlyMachinesDemoWeb.Plugs.FlyReplayHeader.")

    conn
    # |> analyze_conn()
  end

  defp replay(%Conn{} = conn, region) do
    # Is already replayed by proxy?
    if [] != Conn.get_resp_header(conn, "fly-replay") do
      Logger.info("This conn reaches this instance after being replayed by the proxy.")

      conn
      |> analyze_conn()
    else
      Logger.info("This conn asks the proxy to replay the request elsewhere.")

      conn
      |> Conn.put_resp_header("fly-replay", "region=#{region}")
      # |> Conn.put_session(:region, region)
      |> analyze_conn()

      # |> Conn.put_status(:not_found)
      # |> Phoenix.Controller.render(FlyMachinesDemoWeb.ErrorView, :"409")
      # |> Conn.halt()
    end
  end

  defp analyze_conn(%Conn{} = conn) do
    Logger.info("#{inspect(conn.scheme)} #{inspect(conn.method)} #{inspect(conn.path_info)}")
    Logger.info("req_headers:   #{inspect(conn.req_headers)}")
    Logger.info("assigns:       #{inspect(conn.assigns)}")
    Logger.info("resp_headers:  #{inspect(conn.resp_headers)}")
    conn
  end
end
