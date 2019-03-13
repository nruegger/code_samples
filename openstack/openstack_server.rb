class OpenstackServer
  
  def initialize(server)
    logger.info "intialize openstack server from server #{server.hostname}"
    @admin_domain=server.admin_domain
    @admin_user=server.admin_user
    @admin_password=server.admin_password
    @admin_project=server.admin_project
    @region=server.region
    @token=server.token
    @hostname=server.hostname
    @auth_url=server.auth_url
    @compute_url=server.compute_url
    @admin_tenant=server.admin_tenant
    self.auth!
    self.get_instances!
    self.add_direct_link!
    self.get_users!
    self.add_email!
  end
 
  #returns an array of hashes for this openstack server
  def instances
    @instances
  end
  
  #returns the hostname for this openstack server
  def hostname
    @hostname
  end
  
  def users
    @users
  end
  
  #requests an auth token from the openstack server, returns token
  def auth
    logger.info "connecting to openstack server #{@hostname} for auth"
    payload = { 
        auth: { 
          identity: { 
            methods: ["password"],
            password: {
              user: {
                domain: {name: @admin_domain},
                name: @admin_user, 
                password: @admin_password
              } 
            } 
          },
            scope: { 
              project: { 
                domain: { name: @admin_domain },
                name:  @admin_project 
              } 
            } 
          }
        }
    authurl="#{@auth_url}/auth/tokens?nocatalog"
    auth_resp = RestClient::Request.execute(method: :post, :url => authurl, headers: {content_type: "application/json"}, :verify_ssl => false, :payload => payload.to_json)
    logger.info "recieved response, returning new token"
    auth_resp.headers[:x_subject_token]
  end
  
  #requests an auth token from the openstack server, done in place
  def auth!
    @token=self.auth
  end
  
  #uses openstack api to get all instances for an openstack server, returns instances in an array of hashes parsed from json
  def get_instances
    logger.info "getting instances for #{@hostname}"
    compute_url="#{@compute_url}/servers/detail?all_tenants=true"
    response_raw=RestClient::Request.execute(method: :get, :url => compute_url, headers: {"X-Auth-Token" => @token}, :verify_ssl => false)
    json_data = JSON.parse(response_raw.body)["servers"]
    logger.info "recieved #{json_data.count} instances from #{@hostname}"
    json_data
  end
  
  #uses openstack api to get all instances for an openstack server, done in place
  def get_instances!
    @instances=self.get_instances
  end
  
  #returns an array of hashes of instances in the openstack server that adds the hostname and a direct link to each instance hash
  def add_direct_link
    logger.info "adding hostname details for instances on #{@hostname}"
    instances_return=@instances
    instances_return.each do |instance|
      instance["ace_hostname"]=@hostname
      instance["direct_link"]="https://#{@hostname}/project/instances/#{instance["id"]}"
    end
    instances_return
  end
  
  #insterts a value for the openstack server hostname a direct link to an instance on the openstack server, done in place
  def add_direct_link!
    @instances = self.add_direct_link
  end
  
  def add_email
    instances_return=@instances
    instances_return.each do |instance|
      user=@users.select {|user| (user["id"])==(instance["user_id"])}.first
      instance["user_email"]=user["email"]
    end
    instances_return
  end
  
  def add_email!
    @instances = self.add_email
  end
  
  
  
  #takes input sort_param and returns a sorted array of instance hashes for this openstack server
  def instance_sort(sort_param)
    case sort_param
    when "status"
      instances = @instances.sort_by {|hash| hash["status"]}
    when "name"
      instances = @instances.sort_by {|hash| hash["name"]}
    when "updated"
      instances = @instances.sort_by {|hash| hash["updated"]}
    when "region"
      instances = @instances.sort_by {|hash| hash["ace_hostname"]}
    else
      logger.info "caution: sort param #{sort_param} not found, using name" if !(sort_param.empty?)
      instances = @instances.sort_by {|hash| hash["name"]}
    end
    instances  
  end

  #takes input sort_param and sorts the instances for this openstack server in place
  def instance_sort!(sort_param)
    @instances = self.instance_sort(sort_param)
  end
  
  #takes in a status parameter and returns an array of hashes from this 
  def instance_status(status_param)
    @instances.select {|instance| (status_param.downcase)==(instance["status"].downcase)}
  end
  
  def instance_status!(status_param)
    @instances=self.instance_status(status_param)
  end
  
  def instance_updated_ago(days_ago)
    today = Date.today
    filter_date = today - days_ago.to_i
    logger.info "filter date: #{filter_date}"
    @instances.select {|instance| (Date.parse(instance["updated"]))==filter_date}
  end
  
  def instance_updated_ago!(days_ago)
    @instances=self.instance_updated_ago(days_ago)
  end
  
  def instance_updated_before(days_ago)
    today = Date.today
    filter_date = today - days_ago.to_i
    logger.info "filter date: #{filter_date}"
    @instances.select {|instance| (Date.parse(instance["updated"])) < filter_date}
  end
  
  def instance_updated_before!(days_ago)
    @instances=self.instance_updated_before(days_ago)
  end

  def get_users
    logger.info "getting users for #{@hostname}"
    auth_url="#{@auth_url}/users"
    response_raw=RestClient::Request.execute(method: :get, :url => auth_url, headers: {"X-Auth-Token" => @token}, :verify_ssl => false)
    json_data = JSON.parse(response_raw.body)["users"]
    logger.info "recieved #{json_data.count} users from #{@hostname}"
    json_data
  end
  
  def get_users!
    @users=self.get_users
  end
  
  def call_api( call_url, call_headers=nil, call_method=:get)
    if call_headers.nil?
      call_headers={"X-Auth-Token" => @token}
    else
      call_headers.merge({"X-Auth-Token" => @token})
    end
    RestClient::Request.execute(method: call_method, :url => call_url, headers: call_headers, :verify_ssl => false)
  end
  
  def suspend_current
    @instances.each do |instance|
      suspend_instance(instance)
    end
  end
  
  def suspend_instance(instance)
    logger.info "suspending instance #{instance["id"]}"
    compute_url="#{@compute_url}/servers/#{instance["id"]}/action"
    payload="{\"suspend\": null}"
    return_details = RestClient::Request.execute(method: :post, :url => compute_url, headers: {"X-Auth-Token" => @token, content_type: "application/json"}, :verify_ssl => false, :payload => payload)
  end
  
end