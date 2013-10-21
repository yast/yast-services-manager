require 'yast'

module Yast
  import "SystemdTarget"
  import "SystemdService"

  class ServicesManagerClass < Module
    TARGET   = 'default_target'
    SERVICES = 'services'

    def initialize
      textdomain 'services-manager'
    end

    def export
      {
        TARGET   => SystemdTarget.export,
        SERVICES => SystemdService.export
      }
    end

    def import data
      SystemdTarget.import  data[TARGET]
      SystemdService.import data[SERVICES]
    end

    def reset
      SystemdTarget.reset
      SystemdService.reset
    end

    def read
      SystemdTarget.read
      SystemdService.read
    end

    # Saves the current configuration
    #
    # @return Boolean if successful
    def save
      SystemdTarget.save && SystemdService.save
    end

    # Are there any unsaved changes?
    def modified?
      SystemdTarget.modified || SystemdService.modified
    end

    publish({:function => :export,      :type => "map <string, any> ()"          })
    publish({:function => :import,      :type => "boolean ()"                    })
    publish({:function => :modified?,   :type => "boolean ()"                    })
    publish({:function => :read,        :type => "void ()"                       })
    publish({:function => :reset,       :type => "void ()"                       })
    publish({:function => :save,        :type => "map <string, string> (boolean)"})

  end
  ServicesManager = ServicesManagerClass.new
end
