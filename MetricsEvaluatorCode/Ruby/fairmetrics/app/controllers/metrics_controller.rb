#class MetricsController < ApplicationController
class MetricsController < ApiController
  
#  before_action :set_metric, only: [ :show, :edit, :update, :destroy]
  before_action :set_metric, only: [ :show, ]
  skip_before_action :authenticate_request, only: %i[index show new create], raise: false


  # GET /metrics
  # GET /metrics.json
  def index
    @metrics = Metric.all
  end

  # GET /metrics/1
  # GET /metrics/1.json
  def show
  end

  # GET /metrics/new
  def new
    @metric = Metric.new
    @metric
  end

  # GET /metrics/1/edit
  def edit
  end

  # POST /metrics
  # POST /metrics.json
  def create

    @metric = Metric.new(metric_params)  # this will convert API (JSON) calls into application calls v.v. params
    url = @metric[:smarturl]
    url.strip!
    
    if known_metricuri(url)
      @metric.errors[:smarturl_known] << "This metric (by smartURL) already exists - creation failed"
      case request.format.to_s
      when "application/json"
        render json: @collection.errors, status: :unprocessable_entity
        return
      when "text/html"
        render :new
        return
      else 
        render json: @collection.errors, status: :unprocessable_entity
        return
      end

    else
  
      resp = fetch(url)
      if resp
        yaml = YAML.load(resp.body)
        if yaml
          @metric[:name] = yaml["info"]["title"]
          @metric[:description] = yaml["info"]["description"]
          @metric[:principle] = yaml["info"]["applies_to_principle"]
          @metric[:email] = yaml["info"]["contact"]["email"]
          @metric[:creator] = yaml["info"]["contact"]["responsibleDeveloper"] or yaml["info"]["contact"]["responsibleDeveloper"] or "Unidentified"
        else
          @metric.errors[:notyaml] << "The testing endpoint did not return YAML #{resp.body}"
        end
      else
        @metric.errors[:no_response_from_endpoint] << "The testing endpoint did not respond"
      end
      
      if validate then
          # do nothign here for teh moment        
      else
        @metric.errors[:failed_validation] << "Information failed validation - see other errors for details"
      end
      
      if @metric.errors.any?
        respond_to do |format|
          format.html { render :new }
          format.json { render json: @collection.errors, status: :unprocessable_entity }
          return
        end
      end
  
      respond_to do |format|
        if @metric.save
          @collection = Collection.where("name = ?", "__ALL__METRICS")
          collect_all = @collection.first
          collect_all.metrics << @metric
          format.html { redirect_to @metric, notice: 'Metric was successfully created.' }
          format.json { render :show, status: :created, location: @metric }
        else
          @metric.errors[:unknown] << "failed to save for an unknown reason"
          format.html { render :new }
          format.json { render :json => {status: :unprocessable_entity, errors: @notice}}
        end
      end

    end    
  end
  
  
  
  

  # PATCH/PUT /metrics/1
  # PATCH/PUT /metrics/1.json
  def update
    respond_to do |format|
      if @metric.update(metric_params)
        format.html { redirect_to @metric, notice: 'Metric was successfully updated.' }
        format.json { render :show, status: :ok, location: @metric }
      else
        format.html { render :edit }
        format.json { render json: @metric.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /metrics/1
  # DELETE /metrics/1.json
  def destroy
    @metric.destroy
    respond_to do |format|
      format.html { redirect_to metrics_url, notice: 'Metric was successfully destroyed.' }
      format.json { head :no_content }
    end
  end


  def validate
    orcid = @metric.creator
    page = fetch("http://orcid.org/#{orcid}")
    if page and !(page.body.downcase =~ /sign\sin/)
      return true
    else
      @metric.errors[:orcid] << "That was not a valid ORCiD"
      return false
    end
  end
 

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_metric
      @metric = Metric.find(params[:id])
    end



    # Never trust parameters from the scary internet, only allow the white list through.
    def metric_params
      unless params.include?(:metric)  # if not, then this is an API request.  Construct the JSON to make the rest of the code identical
            jsonhash = JSON.parse(request.body.read)
            p = {metric: jsonhash}
         #   logger.debug("\n\n\nfound #{p.class} \n #{p.inspect}\n\n\n")
            params.merge!(p)
         #   logger.debug("\n\n\nfound #{params.inspect}\n\n\n")
      end
#      params.require(:metric).permit(:name, :creator, :email, :principle, :smarturl ,:description)
      params.require(:metric).permit(:smarturl)
    end



    #def fetch(uri_str)  # we create a "fetch" routine that does some basic error-handling.  
    #
    #  address = URI(uri_str)  # create a "URI" object (Uniform Resource Identifier: https://en.wikipedia.org/wiki/Uniform_Resource_Identifier)
    #  response = Net::HTTP.get_response(address)  # use the Net::HTTP object "get_response" method
    #                                               # to call that address
    #
    #  case response   # the "case" block allows you to test various conditions... it is like an "if", but cleaner!
    #    when Net::HTTPSuccess then  # when response Object is of type Net::HTTPSuccess
    #      # successful retrieval of web page
    #      return response  # return that response object to the main code
    #    else
    #      raise Exception, "Something went wrong... the call to #{uri_str} failed; type #{response.class}"
    #      # note - if you want to learn more about Exceptions, and error-handling
    #      # read this page:  http://rubylearning.com/satishtalim/ruby_exceptions.html  
    #      # you can capture the Exception and do something useful with it!
    #      response = False
    #      return response  # now we are returning 'False', and we will check that with an "if" statement in our main code
    #  end 
    #end
    
    def known_metricuri(url)
      # logger.debug("looking for #{url}")
      m = Metric.where('smarturl = ?', url)
      if  m.count > 0
        #logger.debug("found #{url}")
        return true  # exists
      else
        #logger.debug("didnt find #{url}")
        return false  # OK!
      end
    end
    

end
