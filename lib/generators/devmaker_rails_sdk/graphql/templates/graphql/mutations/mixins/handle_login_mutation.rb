module Mutations::Mixins::HandleLoginMutation
  def resolve(params)
    validate_login(params)
  end

  def validate_login(params)
    app = find_doorkeeper_app(params)
    return invalid_client_error unless app

    user = login_considering_users.find_for_database_authentication(email: params[:email])
    return user_not_found_error unless user && user.valid_for_authentication? { user.valid_password?(params[:password]) }

    token = create_access_token_for!(app: app, user: user)

    return {token: token}
  end

  def login_considering_users
    User
  end

  def invalid_client_error
    {errors: [I18n.t("doorkeeper.errors.messages.invalid_client")]}
  end

  def user_not_found_error
    {errors: [I18n.t("devise.failure.not_found_in_database", authentication_keys: "email")]}
  end

  def find_doorkeeper_app(params)
    Doorkeeper::Application.find_by(uid: params[:client_id], secret: params[:client_secret])
  end

  def create_access_token_for!(app:, user:)
    Doorkeeper::AccessToken.create!({
      application: app,
      resource_owner_id: user.id,
      expires_in: Doorkeeper.configuration.access_token_expires_in,
      use_refresh_token: Doorkeeper.configuration.refresh_token_enabled?,
    })
  end

  def generate_token_for(user)
    Doorkeeper::AccessToken.create!(
        application: Doorkeeper::Application.first,
        resource_owner_id: user.id,
        refresh_token: generate_refresh_token,
        expires_in: Doorkeeper.configuration.access_token_expires_in,
        scopes: "",
        )
  end

  def generate_refresh_token
    loop do
      token = SecureRandom.hex(32)
      break token unless Doorkeeper::AccessToken.exists?(refresh_token: token)
    end
  end

end
