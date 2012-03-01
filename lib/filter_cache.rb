# encoding: utf-8

require 'digest/sha1'
require 'dbm'
module Nanoc
  class Filter
    def self.enable_cache(*args)
      args.each do |name|
        cls = named(name)
        cls.class_eval do
          alias _run_old run
          def run(content, params={})
            digest = Digest::SHA1.digest(content + params.hash.to_s)
            DBM.open('tmp/cache.db'){|db|
              (db[digest] ||= _run_old(content, params)).force_encoding 'UTF-8'
            }
          end
        end
      end
    end
  end
end
