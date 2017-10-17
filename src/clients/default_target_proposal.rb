require "yast"
require "services-manager/clients/default_target_proposal"

Yast::TargetProposal.new.call(Yast::WFM.Args)
