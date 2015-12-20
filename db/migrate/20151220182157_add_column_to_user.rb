class AddColumnToUser < ActiveRecord::Migration
  def change
    add_column :users, :app_password, :string
  end
end
