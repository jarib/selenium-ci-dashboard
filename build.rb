class Build
  def initialize(data)
    @data = data
  end

  def as_json(options = nil)
    {
      :state        => state,
      :display_name => display_name,
      :user         => user,
      :revision     => revision,
      :url          => url,
      :params       => params,
      :message      => message
    }
  end

  def state
    result = @data.fetch('result')
    if result.nil? && building?
      :building
    else
      result.downcase.to_sym
    end
  end

  def building?
    @data.fetch('building')
  end

  def url
    @data.fetch('url')
  end

  def display_name
    @data.fetch('fullDisplayName')
  end

  def revision
    (actions_rev || changeset_rev || changeset_items_rev || 'unknown').to_s
  end

  def actions_rev
    params['svnrevision']
  end

  def user
    changeset_item && changeset_item['user']
  end

  def message
    changeset_item && changeset_item['msg']
  end

  def changeset_rev
    revs = @data['changeSet'] && @data['changeSet']['revisions']
    rev = revs && revs.first

    rev['revision'] if rev
  end

  def params
    @params ||= (
      actions = @data['actions']
      params = actions && actions.first && actions.first['parameters']

      result = {}
      if params
        params.each do |obj|
          result[obj['name']] = obj['value']
        end
      end

      result
    )
  end

  def changeset_items_rev
    changeset_item && changeset_item['revision']
  end

  def changeset_item
    if defined? @changeset_item
      @changeset_item
    else
      @changeset_item = (
        cs = @data['changeSet'] && @data['changeSet']['items']
        cs = cs && cs.first
      )
    end
  end
end
