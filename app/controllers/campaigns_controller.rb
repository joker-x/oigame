# encoding: utf-8
class CampaignsController < ApplicationController

  #include Social::Facebook

  protect_from_forgery :except => :sign
  layout 'application', :except => [:widget, :widget_iframe]

  before_filter :authenticate_user!, :only => [:new, :edit, :create, :update, :destroy, :moderated, :activate, :participants, :add_credit]
  before_filter :get_campaign_with_other_campaigns, only: [:signed]
  before_filter :get_campaign, :except => [:index, :feed, :new, :create, :archived]
  before_filter :protect_from_spam, :only => :sign
  before_filter :set_user_blank_parameters, only: :sign

  # comienza la refactorización a muerte
  before_filter :get_sub_oigame

  # TODO: Activate again open graph
  # before_filter :open_graph_facebook, only: methods_for_actions

  # para declarative_auth
  filter_access_to :all, :attribute_check => true
  # para que no se haga check del attributo
  # preguntar a enrique como hacer esto más dry
  filter_access_to :index, :feed, :search, :moderated, :new, :create, :archived

  respond_to :html, :json

  def index
    #if @sub_oigame == 'not found'
    #  render_404
    #  return false
    #end
    @campaigns = Campaign.last_campaigns params[:page], @sub_oigame

    respond_with(@campaigns)
  end

  def show
    # para que funcione el botón de facebook
    @cause = true
    @campaign = Campaign.find(:all, :conditions => {:slug => params[:id], :sub_oigame_id => @sub_oigame}).first

    # metas for facebook
    @meta['title'] = @campaign.name
    @meta['og']['url'] = campaign_url(@campaign,locale:nil)
    @meta['description'] = @campaign.intro
    @meta['og']['type'] = 'oigameapp:campaign'
    @meta['oigameapp']['end_date'] = @campaign.duedate_at.strftime("%Y-%m-%d")

    @participants = @campaign.participants

    @has_participated = @campaign.has_participated?(current_user)

    @stats_data = @campaign.stats
    @image_src = @campaign.image_url.to_s
    @image_file = @campaign.image.file.file
    @description = @campaign.to_html(@campaign.intro).html_safe

    @videotron = UnvlogIt.new(@campaign.video_url) unless @campaign.video_url.blank?

    respond_with(@campaign)
  end

  def new
    @campaign = Campaign.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @campaign }
    end
  end

  def edit
    @campaign = Campaign.find_by_slug(params[:id])
    if @campaign.save
      if @sub_oigame
        redirect_url = sub_oigame_campaign_wizard_path(@sub_oigame, @campaign.slug, :first)
      else 
        redirect_url = campaign_wizard_path(@campaign.slug, :first)
      end
      redirect_to redirect_url

      return
    else
      render :action => :new
    end
  end

  def create
    @campaign = Campaign.new(params[:campaign])
    @campaign.user = current_user
    if @campaign.save
      if @sub_oigame
        @campaign.sub_oigame = @sub_oigame
        redirect_url = sub_oigame_campaign_wizard_path(@sub_oigame, @campaign.slug, :first)
      else
        redirect_url = campaign_wizard_path(@campaign.slug, :first)
      end
      redirect_to redirect_url

      return
    else
      render :action => :new
    end
  end

  def update
    if @campaign.update_attributes(params[:campaign])
      flash[:notice] = 'La campaña fué actualizada con éxito.'
      if @sub_oigame
        redirect_to sub_oigame_campaign_url(@sub_oigame, @campaign)
      else
        redirect_to @campaign
      end
    else
      render :action => :edit
    end
  end

  def destroy
    @campaign.destroy
    flash[:notice] = 'La campaña se eliminió con éxito'
    if @sub_oigame.nil?
      redirect_to campaigns_url
    else
      redirect_to sub_oigame_campaigns_url(@sub_oigame)
    end
  end

  def widget
  end

  def widget_iframe
    render :partial => "widget_iframe"
  end

  def participants
    # Descarga un fichero con el listado de participantes
    #
    # para que funcione el botón de facebook
    @cause = true
    if @sub_oigame
      @campaign = Campaign.find(:all, :conditions => {:slug => params[:id], :sub_oigame_id => @sub_oigame.id}).first
    else
      @campaign = Campaign.find(:all, :conditions => {:slug => params[:id], :sub_oigame_id => nil}).first
    end
    send_data @campaign.participants_list, :type => "text/plain",
              :filename=>"#{@campaign.slug}.txt", :disposition => 'attachment'
  end

  # Types of petitions when {sending, singing}
  def sign
    # Call the model
    model_name = Campaign.types[@campaign.ttype.to_sym][:model_name]
    modelk = model_name.constantize

    from = user_signed_in? ? current_user.email : params[:email]
    user_name = user_signed_in? ? current_user.name : params[:name]

    if @campaign
      # Create the instance of the methok
      instanke = modelk.new
      instanke.campaign = @campaign
      instanke.email = from
      instanke.token = generate_token
      instanke.name = user_name

      if instanke.respond_to? :body
        instanke.body = (params[:own_message] == 1) ? params[:body] : @campaign.default_message_body
      end

      if instanke.respond_to? :subject
        instanke.subject = (params[:own_message] == 1) ? params[:subject] : @campaign.default_message_subject
      end

      if instanke.save
        if user_signed_in?
          instanke.validate!
        else
          validation = "send_message_to_validate_#{model_name.downcase}".to_s
          Mailman.send(validation, from, @campaign.id, instanke.id).deliver
        end
        redirector_to :signed
      else
        redirector_to :campaign, error: "No puedes participar más de una vez por campaña"
      end
    else
      redirector_to :campaigns, error: "Esta campaña ya no está activa."
    end
  end

  def signed
  end

  def validate
    if @campaign
      type_camp = Campaign.types[@campaign.ttype.to_sym][:model_name].constantize
      model = type_camp.find_by_token(params[:token])

      if model
        model.validate!
        redirector_to :signed
      else
        redirector_to :campaign, error: 'El token de validación ya no es válido'
      end

    else
      redirector_to :campaigns, error: 'Está campaña ya no esa activa'
    end
  end

  def integrate
  end

  def moderated
    @campaigns = Campaign.last_campaigns_moderated params[:page], @sub_oigame
  end

  def activate
    @campaign.activate!

    if @sub_oigame.nil? 
      redirect_to @campaign, :notice => 'La campaña se ha activado con éxito'
    else
      redirect_to sub_oigame_campaign_url( @sub_oigame, @campaign ), :notice => 'La campaña se ha activado con éxito'
    end
  end

  def deactivate
    @campaign.deactivate!

    if @sub_oigame.nil? 
      redirect_to @campaign, :notice => 'Campaña desactivada con éxito'
    else
      redirect_to sub_oigame_campaign_url( @sub_oigame, @campaign ), :notice => 'Campaña desactivada con éxito'
    end
  end

  def feed
    @campaigns = Campaign.last_campaigns_without_pagination(10)

    set_http_cache(3.hours, visibility = true)

    respond_to do |format|
      format.rss # feed.rss.builder
      format.json { render json: @campaigns }
    end
  end

  def archive
    @campaign.archive
    if @sub_oigame.nil?
      redirect_to @campaign, :notice => 'La campaña ha sido archivada con éxito'
    else
      redirect_to sub_oigame_campaign_url(@sub_oigame, @campaign), :notice => 'La campaña ha sido archivada con éxito'
    end
  end

  def archived
    @archived = true

    if @sub_oigame.nil?
      @campaigns = Campaign.archived_campaigns params[:page]
    else
      @campaigns = Campaign.archived_campaigns(params[:page], @sub_oigame)
    end
  end

  def prioritize
    @campaign.priority = true
    @campaign.save!
    if @sub_oigame.nil?
      redirect_to @campaign, :notice => 'La campaña ha sido marcada con prioridad'
    else
      redirect_to sub_oigame_campaign_url(@sub_oigame, @campaign), :notice => 'La campaña ha sido marcada con prioridad'
    end
  end

  def deprioritize
    @campaign.priority = false
    @campaign.save!
    if @sub_oigame.nil?
      redirect_to @campaign, :notice => 'La campaña ha sido desmarcada con prioridad'
    else
      redirect_to sub_oigame_campaign_url(@sub_oigame, @campaign), :notice => 'La campaña ha sido desmarcada con prioridad'
    end
  end

  def search
    if params[:q]
      if @sub_oigame.nil?
        # mirar en la deficion de indices lo del no_sub
        @campaigns = Campaign.active.search params[:q], :with => {:no_sub => true }  #, :order => :created_at, :sort => :asc
      else 
        @campaigns = Campaign.active.search params[:q], :conditions => {:sub_oigame_id => @sub_oigame.id}
      end
    end
  end

  #def new_comment
  #  @campaign = Campaign.find(:all, :conditions => {:slug => params[:id], :sub_oigame_id => @sub_oigame}).first
  #  Mailman.inform_new_comment(@campaign).deliver
  #  redirect_to @campaign
  #end

  def add_credit
    unless current_user.ready_for_add_credit
      session[:redirect_to_add_credit] = "#{APP_CONFIG[:domain]}/campaigns/#{@campaign.slug}/add-credit"
      flash[:error] = 'Necesitamos que nos digas tu nombre para poder añadir crédito'
      redirect_to edit_user_registration_url

      return
    end

    @reference = secure_digest(Time.now, (1..10).map { rand.to_s})[0,29]
    
    data = {}
    data[:reference] = @reference
    data[:name] = current_user.name
    data[:email] = current_user.email
    data[:cback] = campaign_url(@campaign)
    HTTParty.post("http://#{APP_CONFIG[:gw_domain]}/pre", :body => data)
  end

  private

  def render_404
    respond_to do |format|
      format.html { render :file => "#{Rails.root}/public/404.html", :status => :not_found, :layout => nil }
      format.xml  { head :not_found }
      format.any  { head :not_found }
    end
  end

  def get_campaign
    @campaign = Campaign.find_by_slug(params[:id])
  end

  def get_campaign_with_other_campaigns
    @campaign = Campaign.find_by_slug(params[:id])
    @campaigns = @campaign.other_campaigns
  end

  def set_user_blank_parameters
    if user_signed_in?
      current_user.update_attributes(:name => params[:name]) if current_user.name.blank?
      current_user.update_attributes(:email => params[:email]) if current_user.name.blank?
    else
      # si no esta registrado seteamos las cookies para no volver a preguntar
      # su nombre y su correo - si esta registrado nos da igual
      cookies[:name] = { :value => params[:name], :expires => 1.year.from_now }
      cookies[:email] = { :value => params[:email], :expires => 1.year.from_now }
    end
  end

  def open_graph_facebook
    session[:fb_sess_campaign] = @campaign.id
    redirect_to facebook_auth_url
  end

  def redirector_to site, params = {}
    t_sub_oigame = @sub_oigame.nil? ? '' : 'sub_oigame_'
    urls = {}
    urls[:campaigns] = "#{t_sub_oigame}campaigns_url".to_s
    urls[:signed] = "signed_#{t_sub_oigame}campaign_url".to_s
    urls[:campaign] = "#{t_sub_oigame}campaign_url".to_s
    redirect_to self.send(urls[site]), params
  end
end
