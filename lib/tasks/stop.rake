# frozen_string_literal: true

desc "stop rails"
task stop: :environment do
  pid_file = "tmp/pids/server.pid"
  pid = File.read(pid_file).to_i
  Process.kill 9, pid
  File.delete pid_file
end
