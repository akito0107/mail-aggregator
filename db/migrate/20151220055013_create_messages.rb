class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :from_address
      t.integer :user_id
      t.text :subject
      t.text :mail_body
      t.text :header

      t.timestamps null: false
    end
  end
end
