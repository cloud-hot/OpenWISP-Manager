class TapTemplate < ActiveRecord::Base
  acts_as_authorization_object :subject_class_name => 'Operator'

  acts_as_markable_on_change :watch_for => [
      :output_band,
      :vlan_templates, :l2vpn_template,
      :bridge_template_id
  ], :notify_on_destroy => :l2vpn_template

  belongs_to :bridge_template
  belongs_to :l2vpn_template, :touch => true

  has_one :l2tc_template, :as => :shapeable_template, :dependent => :destroy

  has_many :vlan_templates, :as => :interface_template, :dependent => :destroy
  has_many :subinterfaces, :as => :interface_template, :class_name => 'VlanTemplate',
           :foreign_key => :interface_template_id, :conditions => { :interface_template_type => 'TapTemplate' }

  # Template instances
  has_many :taps, :dependent => :destroy
  has_many :instances, :class_name => 'Tap', :foreign_key => :tap_template_id

  before_create do |record|
    record.l2tc_template = L2tcTemplate.new( :shapeable_template => record,
                                             :access_point_template => record.l2vpn_template.access_point_template)
  end

  # Update linked template instances 
  after_create do |record|
    # We have a new tap_template
    record.l2vpn_template.l2vpn_clients.each do |v|
      # For each linked template instance, create a new tap and associate it with
      # the corresponding access_point
      nt = v.tap.build( :l2vpn_client => v )
      nt.link_to_template( record )
      unless nt.save
        errors.add_to_base(:cannot_update_linked_instances)
      end
    end
  end

  after_save do |record|
    # Are we saving after a change of bridging status?
    if record.bridge_template_id_changed?
      # Tap changed bridging status/bridge
      record.instances.each do |t|
        # For each linked template instance, opportunely change its bridging status
        if record.bridge_template.nil?
          t.do_unbridge!
        else
          t.do_bridge!(t.l2vpn.machine.bridges.find(:first, :conditions => "bridge_template_id = #{record.bridge_template.id}"))
        end
      end
    end
  end

  def do_bridge!(b)
    self.bridge_template = b
    self.save!
  end

  def do_unbridge!
    self.bridge_template = nil
    self.save!
  end

  # Accessor methods (read)
  def name
    "v#{self.l2vpn_template.id}t#{self.id}"
  end

  def friendly_name
    "layer 2 vpn '#{self.l2vpn_template.l2vpn_server.name}'"
  end

end