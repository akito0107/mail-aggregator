require 'net/imap'
require 'kconv'

module Gmail
  extend ActiveSupport::Concern

  included do

    def check
      subject_attr_name = 'BODY[HEADER.FIELDS (SUBJECT)]'
      body_attr_name = 'BODY[TEXT]'

      imap = Net::IMAP.new('imap.gmail.com', 993, true)
      imap.login(self.email, self.app_password)
      imap.select('INBOX')

      imap.search(['UNSEEN']).each do |msg_id|
        msg = imap.fetch(msg_id, [subject_attr_name, body_attr_name]).first

        envelope = imap.fetch(msg_id, "ENVELOPE")[0].attr["ENVELOPE"]
        sender = envelope.from[0]
        address =  sender.mailbox + '@' +  sender.host
        subject = msg.attr[subject_attr_name].toutf8.strip
        body = msg.attr[body_attr_name].toutf8.strip

        message = self.messages.build(from_address: address, mail_body: body, subject: subject) 
        message.save!
        imap.store(msg_id, '+FLAGS', :Seen)
      end

      imap.logout
      imap.disconnect
    end
  end

end
