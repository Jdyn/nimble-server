defmodule Nimble.UserController do
  use Nimble.Web, :controller

  import Plug.Conn
  import Phoenix.Controller

  alias Nimble.{UserView}
  alias Nimble.Service.{Accounts, Tokens}

  action_fallback Nimble.ErrorController

  @max_age 60 * 60 * 24 * 60 # Valid for 60 days.
  @remember_me_cookie "remember_token"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  def show(conn, _params) do
    token = get_session(conn, :user_token)

    conn
    |> put_status(:ok)
    |> put_remember_token(token)
    |> configure_session(renew: true)
    |> render("show.json", user: conn.assigns[:current_user])
  end

  def show_sessions(conn, _params) do
    current_user = conn.assigns[:current_user]

    tokens = Tokens.find_all(current_user)

    conn
    |> put_status(:ok)
    |> render("sessions.json", tokens: tokens)
  end

  def delete_session(conn, %{"tracking_id" => tracking_id}) do
    current_user = conn.assigns[:current_user]
    with :ok <- Tokens.delete_session_token(current_user, tracking_id) do
      render(conn, "ok.json")
    end
  end

  def delete_sessions(conn, _params) do
    current_user = conn.assigns[:current_user]
    with :ok <- Tokens.delete_session_tokens(current_user, get_session(conn, :user_token)) do
      render(conn, "ok.json")
    end
  end

  @doc """
  Creates a user
  Generates a new User and populates the session
  """
  def sign_up(conn, params) do
    with {:ok, user} <- Accounts.register(params) do
        token = Tokens.create_session_token(user)

        conn
        |> renew_session()
        |> put_session(:user_token, token)
        |> put_remember_token(token)
        |> put_status(:created)
        |> render("show.json", user: user)
    end
  end

  @doc """
  Logs the user in.
  It renews the session ID and clears the whole session
  to avoid fixation attacks.
  """
  def sign_in(conn, %{"email" => email, "password" => password} = _params) do
    # TODO: Add check to see if user is trying to sign in while simultaneously sending
    # a valid session to server.. In that case no need to create new session
    with {:ok, user} <- Accounts.authenticate(email, password) do
        token = Tokens.create_session_token(user)

        conn
        |> renew_session()
        |> put_session(:user_token, token)
        |> put_remember_token(token)
        |> put_status(:ok)
        |> put_view(UserView)
        |> render("login.json", user: user)
    end
  end

  @doc """
  Logs the user out.
  It clears all session data for safety. See renew_session.
  """
  def sign_out(conn, _params) do
    token = get_session(conn, :user_token)
    token && Tokens.delete_session_token(token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> put_status(:ok)
    |> put_view(UserView)
    |> render("ok.json")
  end

  defp put_remember_token(conn, token) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
