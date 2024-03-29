# encoding: utf-8

module Nanoc::Helpers
  module Blogging
    # Returns a string representing the atom feed containing recent articles,
    # sorted by descending creation date.
    #
    # The following attributes must be set on blog articles:
    #
    # * `title` - The title of the blog post
    #
    # * `kind` and `created_at` (described above)
    #
    # The following attributes can optionally be set on blog articles to
    # change the behaviour of the Atom feed:
    #
    # * `excerpt` - An excerpt of the article, which is usually only a few
    #   lines long.
    #
    # * `custom_path_in_feed` - The path that will be used instead of the
    #   normal path in the feed. This can be useful when including
    #   non-outputted items in a feed; such items could have their custom feed
    #   path set to the blog path instead, for example.
    #
    # * `custom_url_in_feed` - The url that will be used instead of the
    #   normal url in the feed (generated from the site's base url + the item
    #   rep's path). This can be useful when building a link-blog where the
    #   URL of article is a remote location.
    #
    # * `updated_at` - The time when the article was last modified. If this
    #   attribute is not present, the `created_at` attribute will be used as
    #   the time when the article was last modified.
    #
    # The site configuration will need to have the following attributes:
    #
    # * `base_url` - The URL to the site, without trailing slash. For
    #   example, if the site is at "http://example.com/", the `base_url`
    #   would be "http://example.com".
    #
    # The feed item will need to know about the feed title, the feed author
    # name, and the URI corresponding to the author. These can be specified
    # using parameters, as attributes in the feed item, or in the site
    # configuration.   
    #
    # * `title` - The title of the feed, which is usually also the title of
    #   the blog.
    #
    # * `author_name` - The name of the item's author.
    #
    # * `author_uri` - The URI for the item's author, such as the author's
    #   web site URL.
    #
    # The feed item can have the following optional attributes:
    #
    # * `feed_url` - The custom URL of the feed. This can be useful when the
    #   private feed URL shouldn't be exposed; for example, when using
    #   FeedBurner this would be set to the public FeedBurner URL.
    #
    # To construct a feed, create a new item and make sure that it is
    # filtered with `:erb` or `:erubis`; it should not be laid out. Ensure
    # that it is routed to the proper path, e.g. `/blog.xml`. It may also be
    # useful to set the `is_hidden` attribute to true, so that helpers such
    # as the sitemap helper will ignore the item. The content of the feed
    # item should be `<%= atom_feed %>`.
    #
    # @example Defining compilation and routing rules for a feed item
    #
    #   compile '/blog/feed/' do
    #     filter :erb
    #   end
    #
    #   route '/blog/feed/' do
    #     '/blog.xml'
    #   end
    #
    # @example Limiting the number of items in a feed
    #
    #   <%= atom_feed :limit => 5 %>
    #
    # @option params [Number] :limit (5) The maximum number of articles to
    #   show
    #
    # @option params [Array] :articles (sorted_articles) A list of articles to
    #   include in the feed
    #
    # @option params [Proc] :content_proc (->{ |article|
    #   article.compiled_content(:snapshot => :pre) }) A proc that returns the
    #   content of the given article, which is passed as a parameter. This
    #   function may not return nil.
    #
    # @option params [proc] :excerpt_proc (->{ |article| article[:excerpt] })
    #   A proc that returns the excerpt of the given article, passed as a
    #   parameter. This function should return nil if there is no excerpt.
    #
    # @option params [String] :title The feed's title, if it is not given in
    #   the item attributes.
    #
    # @option params [String] :author_name The name of the feed's author, if
    #   it is not given in the item attributes.
    #
    # @option params [String] :author_uri The URI of the feed's author, if it
    #   is not given in the item attributes.
    #
    # @return [String] The generated feed content
    def atom_feed(params={})
      require 'builder'

      # Extract parameters
      limit             = params[:limit] || 5
      relevant_articles = params[:articles] || articles || []
      content_proc      = params[:content_proc] || lambda { |a| a.compiled_content(:snapshot => :pre) }
      excerpt_proc      = params[:excerpt_proc] || lambda { |a| a[:excerpt] }

      # Check config attributes
      if @site.config[:base_url].nil?
        raise RuntimeError.new('Cannot build Atom feed: site configuration has no base_url')
      end

      # Check feed item attributes
      title = params[:title] || @item[:title] || @site.config[:title]
      if title.nil?
        raise RuntimeError.new('Cannot build Atom feed: no title in params, item or site config')
      end
      author_name = params[:author_name] || @item[:author_name] || @site.config[:author_name]
      if author_name.nil?
        raise RuntimeError.new('Cannot build Atom feed: no author_name in params, item or site config')
      end
      author_uri = params[:author_uri] || @item[:author_uri] || @site.config[:author_uri]
      if author_uri.nil?
        raise RuntimeError.new('Cannot build Atom feed: no author_uri in params, item or site config')
      end

      # Check article attributes
      if relevant_articles.empty?
        raise RuntimeError.new('Cannot build Atom feed: no articles')
      end
      if relevant_articles.any? { |a| a[:created_at].nil? }
        raise RuntimeError.new('Cannot build Atom feed: one or more articles lack created_at')
      end

      # Get sorted relevant articles
      sorted_relevant_articles = relevant_articles.sort_by do |a|
        attribute_to_time(a[:updated_at] || a[:created_at])
      end.reverse.first(limit)

      # Get most recent article
      last_article = sorted_relevant_articles.first

      # Create builder
      buffer = ''
      xml = Builder::XmlMarkup.new(:target => buffer, :indent => 2)

      # Build feed
      xml.instruct!
      xml.feed(:xmlns => 'http://www.w3.org/2005/Atom') do
        root_url = @site.config[:base_url] + '/'

        # Add primary attributes
        xml.id      root_url
        xml.title   title

        # Add date
        xml.updated(attribute_to_time(last_article[:created_at]).to_iso8601_time)

        # Add links
        xml.link(:rel => 'alternate', :href => root_url)
        xml.link(:rel => 'self',      :href => feed_url)

        # Add author information
        xml.author do
          xml.name  author_name
          xml.uri   author_uri
        end

        # Add articles
        sorted_relevant_articles.each do |a|
          # Get URL
          url = url_for(a)
          next if url.nil?

          xml.entry do
            # Add primary attributes
            xml.id        atom_tag_for(a)
            xml.title     a[:title], :type => 'html'

            # Add dates
            xml.published attribute_to_time(a[:created_at]).to_iso8601_time
            xml.updated   attribute_to_time(a[:updated_at] || a[:created_at]).to_iso8601_time
        
            # Add specific author information
            if a[:author_name] || a[:author_uri]
              xml.author do
                xml.name  a[:author_name] || author_name
                xml.uri   a[:author_uri]  || author_uri
              end
            end

            # Add link
            xml.link(:rel => 'alternate', :href => url)

            # Add content
            summary = excerpt_proc.call(a)
            xml.content   content_proc.call(a), :type => 'html'
            xml.summary   summary, :type => 'html' unless summary.nil?
          end
        end
      end

      buffer
    end
    # Returns an URI containing an unique ID for the given item. This will be
    # used in the Atom feed to uniquely identify articles. These IDs are
    # created using a procedure suggested by Mark Pilgrim and described in his
    # ["How to make a good ID in Atom" blog post]
    # (http://diveintomark.org/archives/2004/05/28/howto-atom-id).
    #
    # @param [Nanoc::Item] item The item for which to create an atom tag
    #
    # @return [String] The atom tag for the given item
    def atom_tag_for(item)
      @site.config[:base_url] + item.path + '#id'
    end

    # Converts the given attribute (which can be a string, a Time or a Date)
    # into a Time.
    #
    # @param [String, Time, Date] time Something that contains time
    #   information but is not necessarily a Time instance yet
    #
    # @return [Time] The Time instance corresponding to the given input
    def attribute_to_time(time)
      time = Time.local(time.year, time.month, time.day) if time.is_a?(Date)
      time = Time.parse(time) if time.is_a?(String)
      time
    end

    def sorted_updated_articles
      articles.sort_by{|item|item[:updated_at] || item[:created_at]}.reverse
    end
  end
end
