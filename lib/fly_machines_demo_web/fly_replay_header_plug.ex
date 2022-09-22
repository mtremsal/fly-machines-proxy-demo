defmodule FlyMachinesDemoWeb.Plugs.FlyReplayHeader do
  alias Plug.Conn

  require Logger

  def init(opts), do: opts

  # Replay requests to /gameserver
  def call(%Conn{path_info: ["gameserver" | path_info_tail]} = conn, _opts) do
    region = hd(path_info_tail)

    conn
    # |> Conn.put_session(:region, region)
    |> replay(region)
  end

  # Analyze all other requests
  def call(%Conn{} = conn, _opts) do
    Logger.info("This conn bypassed FlyMachinesDemoWeb.Plugs.FlyReplayHeader.")

    conn
    |> analyze_conn()
  end

  defp replay(%Conn{} = conn, region) do
    # Is already replayed by proxy?
    if [] != Conn.get_req_header(conn, "fly-replay-src") do
      Logger.info("This conn reaches this instance after being replayed by the proxy.")

      conn
      |> analyze_conn()
    else
      Logger.info("This conn asks the proxy to replay the request elsewhere.")

      conn
      |> Conn.put_resp_header("fly-replay", "region=#{region}")
      |> analyze_conn()
    end
  end

  defp analyze_conn(%Conn{} = conn) do
    Logger.debug("#{inspect(conn.scheme)} #{inspect(conn.method)} #{inspect(conn.path_info)}")
    Logger.debug("req_headers:   #{inspect(conn.req_headers)}")
    Logger.debug("assigns:       #{inspect(conn.assigns)}")
    Logger.debug("resp_headers:  #{inspect(conn.resp_headers)}")
    # Logger.debug("session:       #{inspect(conn |> Conn.get_session())}")
    conn
  end
end
