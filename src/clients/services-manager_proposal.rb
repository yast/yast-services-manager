class ServicesManagerProposal < Yast::Client
  Yast.import 'ServicesManager'

  def initialize
    textdomain 'services-manager'
    function = WFM.Args.first.to_s

    case function
      when 'MakeProposal' then make_proposal
      when 'AskUser'      then ask_user
      when 'Description'  then description
      when 'Write'        then write
    end
  end

  def ask_user
  end

  # Return a map with 3 items:
  # id => unique widget id as string
  # menu_title => translated menu with keyboard shortcut for button widget
  # rich_text_tile => translated title as plain string
  def description
  end

  def make_proposal
  end

  def write
  end
end

ServicesManagerProposal.new
