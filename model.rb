# -*- encoding : utf-8 -*-

require 'data_mapper'

configure :production do
  DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/production.db")
  DataMapper::Model.raise_on_save_failure = false
end

configure :test do
  DataMapper.setup(:default, "sqlite::memory:")
  DataMapper::Model.raise_on_save_failure = true
end

configure :development do
  DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/development.db")
  DataMapper::Model.raise_on_save_failure = true
end

class Language
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true
  has n, :words

  validates_uniqueness_of :name
end

class Word
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true
  belongs_to :language

  validates_uniqueness_of :name, :scope => :language

  def translations
    a = TranslationPair.all(first: self).map { |pair| pair.second }
    b = TranslationPair.all(second: self).map { |pair| pair.first }
    a | b
  end

  def add_translation(word)
    TranslationPair.add(self, word)
  end
end

class TranslationPair
  include DataMapper::Resource

  belongs_to :first, 'Word', :key => true
  belongs_to :second, 'Word', :key => true

  validates_uniqueness_of :first, :scope => :second

  # Translation is symmetric relation. To prevent redundancy we only allow entries
  # which have first_id less than second_id. It simplifies validating uniqueness.
  validates_with_block do
    if self.first and self.second and self.first.id < self.second.id
      true
    else
      [false, "first_id must be less than second_id"]
    end
  end

  # Validate if words are in different languages. Adding translation to word
  # in the same language doesn't make sense. It isn't synonym dictionary.
  validates_with_block do
    if self.first and self.second and self.first.language != self.second.language
      true
    else
      [false, "words' languages must be different"]
    end
  end

  def self.add(a, b)
    if a.id > b.id then a, b = b, a end
    TranslationPair.first_or_create(first: a, second: b)
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!
