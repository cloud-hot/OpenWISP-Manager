class Tap < ActiveRecord::Base
  acts_as_authorization_object :subject_class_name => 'Operator'

  acts_as_markable_on_change :watch_for => [
      :output_band, :vlans
  ]

  belongs_to :l2vpn, :polymorphic => true, :touch => true
  
  belongs_to :bridge
  
  has_many :vlans, :as => :interface, :dependent => :destroy
  has_many :subinterfaces, :as => :interface, :class_name => 'Vlan',
    :foreign_key => :interface_id, :conditions => { :interface_type => 'Tap' }
  has_one :l2tc, :as => :shapeable, :dependent => :destroy

  # Instance template
  belongs_to :tap_template
  belongs_to :template, :class_name => 'TapTemplate', :foreign_key => :tap_template_id

  def belongs_to_access_point?
    self.machine.class == AccessPoint
  end

  def link_to_template(t)
    self.template = t
    
    # Create (and link to appropriate templates) subinterfaces (i.e.: vlans)
    t.vlan_templates.each do |vt|
      nv = self.vlans.build( :interface => self )
      nv.link_to_template( vt )
      unless nv.save!
        raise ActiveRecord::Rollback
      end
    end
    
    # Create a new l2tc profile for this interface
    nl = self.l2tc = L2tc.new( :access_point => self.machine, :shapeable => self )
    nl.link_to_template(template.l2tc_template)
    unless nl.save!
      raise ActiveRecord::Rollback
    end
  end

  def do_bridge!(b)
    self.bridge = b
    self.save!
  end

  def do_unbridge!
    self.bridge = nil
    self.save!
  end

  # Accessor methods (read)
  def name
    if self.template.nil?
      "v#{self.l2vpn.id}t#{self.id}"
    else
      "v#{self.l2vpn.template.id}t#{self.template.id}"
    end
  end

  def friendly_name
    "layer 2 vpn '#{self.l2vpn.name}'"
  end

  def output_band
    if (read_attribute(:output_band).blank? or read_attribute(:output_band).nil?) and !template.nil?
      return template.output_band
    end

    read_attribute(:output_band)
  end

  def machine
    self.l2vpn.machine
  end

end