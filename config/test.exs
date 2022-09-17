import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fly_machines_demo, FlyMachinesDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jHJ8q2a0vGjG9P72zQDQG6MTDYfIXRZ+umuIq6J4MFnIv5lLOzH4Jr3E/tX0es3+",
  server: false

# In test we don't send emails.
config :fly_machines_demo, FlyMachinesDemo.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
