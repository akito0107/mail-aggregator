json.array!(@messages) do |message|
  json.extract! message, :id, :from_address, :user_id, :subject, :mail_body, :header
  json.url message_url(message, format: :json)
end
