
class Sass::ZipImporter::Importer < Sass::Importers::Base

  attr_reader :zip_file
  
  def extensions
    {
      ".scss" => :scss,
      ".css" => :scss,
      ".sass" => :sass
    }
  end

  def initialize(zip_file)
    require 'zip/zip'
    require 'pathname'
    @zip_file = File.expand_path(zip_file)
  end

  # Enable watching of css files in Sass 3.3+
  def watched_directories
    [File.dirname(zip_file)]
  end

  # Enable watching of css files in Sass 3.3+
  def watched_file?(file)
    zip_file == file
  end

  def find_relative(name, base, options)
    base = base.split("!", 2).last
    if entry = entry_for(name, base)
      engine(entry, options)
    end
  end


  def find(name, options)
    if entry = entry_for(name)
      engine(entry, options)
    end
  end

  def engine(entry, options)
    options[:syntax] = extensions.fetch(File.extname(entry.name), :scss)
    options[:filename] = full_filename(entry)
    options[:importer] = self
    Sass::Engine.new(zip.read(entry), options)
  end
  

  def mtime(name, options)
    if entry = entry_for(name)
      entry.time
    end
    nil
  end

  def key(name, options)
    name.split("!", 2)
  end

  def to_s
    zip_file
  end

  def eql?(other)
    other.class == self.class && other.zip_file == self.zip_file
  end

  protected

  def full_filename(entry)
    "#{zip_file}!#{entry.name}"
  end

  def entry_for(name, base = nil)
    possible_names(name, base).each do |n|
      if entry = zip.find_entry(n)
        return entry
      end
    end
    nil
  end

  def possible_names(name, base = nil)
    if base
      absolute_root = Pathname.new("/")
      base_path = Pathname.new(base)
      path = Pathname.new(name)
      begin
        name = absolute_root.join(base_path).dirname.join(path).relative_path_from(absolute_root).to_s
      rescue
        # couldn't create a relative path, so we'll just assume it's absolute or for a different importer.
        return []
      end
    end
    d, b = File.split(name)
    names = if b.start_with?("_")
              [name]
            else
              [name, d == "." ? "_#{b}" : "#{d}/_#{b}"]
            end

    names.map do |n|
      if (ext = File.extname(n)).size > 0 && extensions.keys.include?(ext)
        n
      else
        extensions.keys.map{|k| "#{n}#{k}" }
      end
    end.flatten
  end

  def zip
    @zip ||= open_zip_file!
  end

  def open_zip_file!
    z = Zip::ZipFile.open(zip_file)
    at_exit { z.close }
    z
  end

end