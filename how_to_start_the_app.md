# Start the app

- If you have Elixir (1.18) installed:  
  `iex ./app.exs`

- If you have Nix installed:  
  `nix develop` then `iex ./app.exs`

- If you have Podman installed:  
  `./start_within_container_with_podman.sh`

- If you have Docker installed:  
  Change all `podman` occurrences in the script `./start_within_container_with_docker.sh` for `docker`, then run:  
  `./start_within_container_with_docker.sh`

# Try the app

Open your browser at `http://localhost:5001/`  
Click on some buttons
