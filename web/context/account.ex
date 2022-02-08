defmodule Nimble.Account do
  alias Nimble.Repo
  alias Nimble.{User, UserToken, UserNotifier}

  @doc """
  Retrieve a User by a parameter that exists on a %User{} struct.
  ## Examples
      iex> find_by(email: "test@test.com")
      %User{}

      iex> find_by(id: 105)
      nil
  """
  def find_by(param) do
    Repo.get_by(User, param)
  end

  @doc """
  Retrieve a User by a given signed session token.
  """
  def find_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    with %User{} = user <- find_by(email: email),
         true <- User.valid_password?(user, password) do
      {:ok, user}
    else
      _ ->
        {:unauthorized, "Email or Password is incorrect."}
    end
  end

  @doc """
  Registers a user.

  ## Examples
      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def register(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  ## Examples
      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user e-mail.
  ## Examples
      iex> change_email(user)
      %Ecto.Changeset{data: %User{}}
  """
  def change_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Emulates that the e-mail will change without actually changing
  it in the database.
  ## Examples
      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}
  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user e-mail in token.
  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.
  ## Examples
      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}
  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  @doc """
  Updates the user password.
  ## Examples
      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}
  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Confirmation

  @doc """
  Confirms a user by the given token.
  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ ->
        {:not_found, "Your link is either invalid, or your email has already been confirmed."}
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Gets the user by reset password token.
  ## Examples
      iex> get_user_by_reset_password_token("validtoken")
      %User{}
      iex> get_user_by_reset_password_token("invalidtoken")
      nil
  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Gets a user by email.
  ## Examples
      iex> get_user_by_email("foo@example.com")
      %User{}
      iex> get_user_by_email("unknown@example.com")
      nil
  """
  def get_user_by_email(email) when is_binary(email), do: Repo.get_by(User, email: email)

  @doc """
  Resets the user password.
  ## Examples
      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}
      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}
  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Delivers the confirmation email instructions to the given user.
  ## Examples
      iex> deliver_user_confirmation_instructions(user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}
      iex> deliver_user_confirmation_instructions(confirmed_user, &Routes.user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}
  """
  def deliver_user_confirmation_instructions(%User{} = user) do
    if user.confirmed_at do
      {:not_found, "Your email has already been confirmed."}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, encoded_token)
      :ok
    end
  end

  @doc """
  Generates a session token.
  """
  def create_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Deletes the current session token.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  def delete_session_token(%User{} = user, tracking_id) do
    if _token = Repo.one(UserToken.user_and_tracking_id_query(user, tracking_id)) do
      Repo.delete_all(UserToken.user_and_tracking_id_query(user, tracking_id))
      :ok
    else
      {:not_found, "Session does not exist."}
    end
  end

  @doc """
  Deletes all session tokens except current session.
  """
  def delete_session_tokens(%User{} = user, token) do
    Repo.delete_all(UserToken.user_and_session_tokens(user, token))
    :ok
  end

  @doc """
  Returns all tokens for the given user.
  """
  def find_all(user) do
    UserToken.user_and_contexts_query(user, :all)
    |> Repo.all()
  end

  def find_all_sessions(user) do
    UserToken.user_and_session_tokens(user)
    |> Repo.all()
  end
end
