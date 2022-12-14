defmodule FlyMachinesDemoWeb.NavComponentLive do
  use FlyMachinesDemoWeb, :live_component

  @regions %{"ewr" => "πΊπΈ", "nrt" => "π―π΅", "cdg" => "π«π·"}

  def get_flag(region), do: @regions |> Map.get(region, "π©")

  def get_flag(), do: @regions |> Map.get(System.get_env("FLY_REGION", nil), "π©")

end
