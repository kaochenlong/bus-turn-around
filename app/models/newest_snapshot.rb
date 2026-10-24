# The external snapshot with the latest date in its file name, of the files
# named <YYYY-MM-DD>.csv in one folder of the data root. derived:load and the
# end nature survey look up the MRT entrance and public toilet snapshots this
# way.
module NewestSnapshot
  # A snapshot: the file and the date in its name.
  Snapshot = Data.define(:path, :day)

  # The folder holds no snapshot; the message names the task that writes one.
  class Missing < StandardError; end

  NAME = /\A\d{4}-\d{2}-\d{2}\.csv\z/

  # `directory` is relative to the data root; `label` names the snapshot and
  # `task` the command that writes it, both for the message when none is there.
  def self.find(data_root:, directory:, label:, task:)
    directory = File.join(data_root, directory)
    name = Dir.glob("*.csv", base: directory).grep(NAME).max
    raise Missing, "沒有#{label}快照：先跑 #{task}" unless name

    Snapshot.new(path: File.join(directory, name), day: Date.iso8601(File.basename(name, ".csv")))
  end
end
