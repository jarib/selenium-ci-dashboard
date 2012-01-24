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
      :url          => url
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
    @data.fetch('displayName')
  end

  def revision
    (actions_rev || changeset_rev || 'unknown').to_s
  end

  def actions_rev
    actions = @data.fetch('actions') or return
    action  = actions.first or return
    params  = action['parameters'] or return
    rev     = action['parameters'].find { |e| e['name'] == "svnrevision" } or return

    rev['value']
  end

  def user
    changeset && changeset['user']
  end

  def changeset_rev
    changeset && changeset['revision']
  end

  def changeset
    if defined? @cs
      @cs
    else
      @cs = (
        cs = @data['changeSet'] && @data['changeSet']['items']
        cs = cs && cs.first
      )
    end
  end
end
