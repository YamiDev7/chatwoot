# TODO: lets use HTTParty instead of RestClient
class ChatwootHub
  DEFAULT_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  def self.base_url
    DEFAULT_BASE_URL
  end

  def self.ping_url
    "#{base_url}/ping"
  end

  def self.registration_url
    "#{base_url}/instances"
  end

  def self.push_notification_url
    "#{base_url}/send_push"
  end

  def self.events_url
    "#{base_url}/events"
  end

  def self.billing_base_url
    "#{base_url}/billing"
  end

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    "#{billing_base_url}?installation_identifier=#{installation_identifier}"
  end

  def self.pricing_plan
    return 'enterprise' unless ChatwootApp.enterprise?

    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'
  end

  def self.pricing_plan_quantity
    return 999999 unless ChatwootApp.enterprise?

    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.value || 0
  end

  def self.support_config
    {
      support_website_token: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN')&.value,
      support_script_url: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_SCRIPT_URL')&.value,
      support_identifier_hash: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH')&.value
    }
  end

  def self.instance_config
    {
      installation_identifier: installation_identifier,
      installation_version: Chatwoot.config[:version],
      installation_host: URI.parse(ENV.fetch('FRONTEND_URL', '')).host,
      installation_env: ENV.fetch('INSTALLATION_ENV', ''),
      edition: ENV.fetch('CW_EDITION', '')
    }
  end

  def self.instance_metrics
    {
      accounts_count: fetch_count(Account),
      users_count: fetch_count(User),
      inboxes_count: fetch_count(Inbox),
      conversations_count: fetch_count(Conversation),
      incoming_messages_count: fetch_count(Message.incoming),
      outgoing_messages_count: fetch_count(Message.outgoing),
      additional_information: {}
    }
  end

  def self.fetch_count(model)
    model.last&.id || 0
  end

  def self.sync_with_hub
    # Telemetry disabled - no data sent
    return {}
  end

  def self.register_instance(company_name, owner_name, owner_email)
    # Telemetry disabled - no data sent
      return true
  end

  def self.send_push(fcm_options)
    # Telemetry disabled - no push modifications sent via hub
      return true
  end

  def self.emit_event(event_name, event_data)
    # Telemetry disabled - no events sent
      return true
  end
end

ChatwootHub.singleton_class.prepend_mod_with('ChatwootHub')
