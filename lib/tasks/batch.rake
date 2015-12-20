namespace :batch do
  task :aggregate => :environment do
    users = User.all()

    users.each do |user|
      user.check
    end

  end
end
