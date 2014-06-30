# Neomirror

Lightweight but flexible gem that allows reflect some of data from relational database into neo4j.<br />
This allows to perform faster and easier search of your models ids<br />
or it can be first step of migrating application data to neo4j.<br />
Uses [Neography](https://github.com/maxdemarzi/neography) (wrapper of Neo4j Rest API).
Gem was inspired by [Neoid](https://github.com/neoid-gem/neoid)

## Installation

Add this line to your application's Gemfile:

    gem 'neomirror'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install neomirror

## Configuration

For more configuration options please read about Neography [Configuration and initialization](https://github.com/maxdemarzi/neography/wiki/Configuration-and-initialization)

```ruby
Neography.configure do |config|
  config.protocol = "http://"
  config.server = "localhost"
  config.port = 7474
  config.username = nil
  config.password = nil
end

Neomirror.connection = Neography::Rest.new
```

## Usage

### Reflect model as node (vertex).


```ruby
class User < ActiveRecord::Base
  include Neomirror::Node

  mirror_neo_node label: :User do # option :label is optional
    property :name
    property :name_length, ->(record) { record.name.length }
  end
end

user = User.create(name: 'Dougal')
# Find or create neo node.
user.neo_node # => #<Neography::Node id=...> 
user.node # Alias of #neo_node
user.find_neo_node # => #<Neography::Node id=...> 
```

Primary key is saved automatically for nodes as `id` attribute. Also unique constraint is created. Creating a unique constraint also creates a unique index (which is faster than a regular index).

For `ActiveRecord` methods `#create_neo_node`, `#update_neo_node`, `#destroy_neo_node` are called on corresponding callbacks (`after_create`, `after_update`, `after_destroy`).

### Reflect model as one or several relationships (edges).

```ruby
class Membership < ActiveRecord::Base
  include Neomirror::Relationship
  belongs_to :premises
  belongs_to :group

  mirror_neo_relationship start_node: :premises, end_node: :group, type: :MEMBER_OF
end

membership = Membership.first
# Find or create neo relationship.
membership.neo_relationship # => #<Neography::Relationship> or nil unless both nodes present
membership.neo_rel # Alias of #neo_relationship
```

For `ActiveRecord` methods `#create_neo_relationships`, `#update_neo_relationships`, `#destroy_neo_relationships` are called on corresponding callbacks (`after_create`, `after_update`, `after_destroy`).

#### Reflect and retrieve several relationships for model.

```ruby
class Staff < ActiveRecord::Base
  include Neomirror::Relationship
  belongs_to :user
  belongs_to :premises
  belongs_to :group

  mirror_neo_relationship start_node: :user, end_node: :premises, type: :STAFF_OF
  mirror_neo_relationship start_node: :user, end_node: :group, type: :STAFF_OF
end

staff = Staff.first
staff.neo_relationship(end_node: :premises) # => #<Neography::Relationship> or nil
staff.neo_relationship(end_node: :group)    # => #<Neography::Relationship> or nil
```

## Migration of existing data

```ruby
Premises.find_each(&:create_neo_node)
Group.find_each(&:create_neo_node)
Membership.preload(:premises, :group).find_each(&:create_neo_relationships)
User.find_each(&:create_neo_node)
Staff.preload(:premises, :group).find_each(&:create_neo_relationships)
```
Note that `#create_neo_node` method will raise exception for already existed node and `#create_neo_relationships` will create duplicated relationships for existed relationships.

Also can use `#neo_node` and `#neo_relationship` methods which find or create.

```ruby
Premises.find_each(&:neo_node)
Group.find_each(&:neo_node)
Membership.preload(:premises, :group).find_each(&:neo_relationship)
User.find_each(&:neo_node)
Staff.preload(:premises, :group).find_each do |staff|
  staff.neo_relationship(end_node: :premises)
  staff.neo_relationship(end_node: :group)
end
```

## Clear neo4j

```ruby
Neomirror.neo.execute_query("START n=node(*) OPTIONAL MATCH n-[r]-() DELETE n,r")
```

## Reflect model as bunch of optional relationships

Sometimes there is choise how to reflect relationship. Model which is representation of relationship can be mapped as edge with properties or as bunch of edges. Both design decisions are possible with neomirror.

Reflect model as relationship (edge) with properties.

```ruby
class Staff < ActiveRecord::Base
  include Neomirror::Relationship
  belongs_to :user
  belongs_to :premises

  mirror_neo_relationship start_node: :user, end_node: :premises, type: :STAFF_OF do
    property :roles
  end
end
```

Reflect model as bunch of optional relationships (edges) existence of which depends on the respective condition. On model create edge created only if predicate evaluates as true. On model update edge will be deleted if predicate evaluates as false.

```ruby
class Staff < ActiveRecord::Base
  include Neomirror::Relationship
  belongs_to :user
  belongs_to :premises

  mirror_neo_relationship start_node: :user, end_node: :premises, type: :MANAGER_OF,
    if: ->(r) { r.roles.include?('manager') }

  mirror_neo_relationship start_node: :user, end_node: :premises, type: :VISITOR_OF,
    if: ->(r) { r.roles.include?('visitor') }
end
```

Even possible reflect model as node (vertex) and relation(s) (edge). But it is probably not needed.

## Compatibility

It is possible to use it outside of ActiveRecord (there is no dependency). Just use methods `create_neo_node`, `update_neo_node` and `destroy_neo_node` in your callbaks for nodes and `create_neo_relationships`, `update_neo_relationships` and `destroy_neo_relationships` for relationships.

Also specify primary key attribute if it is differ from `id` and class don't `respond_to? :primary_key` method.

```ruby
class Postcode
  attr_accessor :code
  include Neomirror::Node

  self.node_primary_key = :code

  mirror_neo_node
end

p = Postcode.new
p.code = 'ABC'
p.create_neo_node # => #<Neography::Node id="ABC">
```

## Contributing

1. Fork it ( http://github.com/shhavel/neomirror/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
