require 'sinatra'
require 'stripe'
require 'dotenv'
require 'json'
require 'encrypted_cookie'

Dotenv.load
Stripe.api_key = ENV['STRIPE_TEST_SECRET_KEY']

use Rack::Session::EncryptedCookie,
  :secret => 'replace_me_with_a_real_secret_key' # Actually use something secret here!

get '/' do
  status 200
  return "Mani Payment POC Backend All Set"
end

post '/charge' do
  authenticate!
  # Get the credit card details submitted by the form
  source = params[:source]

  # Create the charge on Stripe's servers - this will charge the user's card
  begin
    charge = Stripe::Charge.create(
      :amount => params[:amount], # this number should be in cents
      :currency => "usd",
      :customer => @customer.id,
      :source => source,
      :description => "Example Charge"
    )
  rescue Stripe::StripeError => e
    status 402
    return "Error creating charge: #{e.message}"
  end

  status 200
  return "Charge successfully created"
end

get '/customer' do
  authenticate!
  status 200
  content_type :json
  @customer.to_json
end

post '/customer' do
    #authenticate!
    # Get the credit card details submitted by the form
    body_parameters = request.body.read
    params.merge!(JSON.parse(body_parameters))
    
    email = params[:email]
    
    # Create the user by email
    begin
        newCustomer = Stripe::Customer.create(:email => email)
                                       rescue Stripe::InvalidRequestError
                                       return "Error creating charge: #{e.message}"
    end
    
    status 200
    
    content_type :json
    return newCustomer.to_json
    #return
end

post '/customer/createCard' do
    
    body_parameters = request.body.read
    params.merge!(JSON.parse(body_parameters))
    
    
    customerP = params[:customer]
    numberP = params[:number]
    monthP = params[:exp_month]
    yearP = params[:exp_year]
    cvcP = params[:cvc]
    
    
    begin
    token = Stripe::Token.create(
                                 :card => {
                                 :number => numberP,
                                 :exp_month => monthP,
                                 :exp_year => yearP,
                                 :cvc => cvcP
                                 },
                                 )
    rescue Stripe::StripeError => e
    status 401
    return "Error retrieving customer: #{e.message}"
    end
                                 begin
                                     cu = Stripe::Customer.retrieve(customerP)
                                     rescue Stripe::StripeError => e
                                     status 402
                                     return "Error retrieving customer: #{e.message}"
                                 end
                                 
                                 cu.card = token.id
                                 cu.save
                                 
                                 status 200
                                 
                                 content_type :json
                                 return cu.to_json
end



post '/customer/subscribe' do
    #authenticate!
    # Get the credit card details submitted by the form
    body_parameters = request.body.read
    params.merge!(JSON.parse(body_parameters))
    
    customerP = params[:customer]
    planP = params[:plan]
    
    #return params.to_json
    # Create the user by email
    begin
        cu = Stripe::Customer.retrieve(customerP)
        rescue Stripe::StripeError => e
        status 402
        return "Error retrieving customer: #{e.message}"
    end
    
    
    begin
        plan = Stripe::Plan.retrieve(planP)
        sub = cu.subscriptions.create(plan: plan)
        rescue Stripe::StripeError => e
        status 402
        return "Error creating subscription: #{e.message}"
        
    end
    
    status 200
    
    content_type :json
    return sub.to_json
    #return
end

post '/customer/upgrade' do
    #authenticate!
    # Get the credit card details submitted by the form
    body_parameters = request.body.read
    params.merge!(JSON.parse(body_parameters))
    
    customerP = params[:customer]
    subscriptionP = params[:subscription]
    planP = params[:plan]
    
    begin
        cu = Stripe::Customer.retrieve(customerP)
        rescue Stripe::StripeError => e
        status 402
        return "Error retrieving customer: #{e.message}"
    end
    
     begin
        subscription = cu.subscriptions.retrieve(subscriptionP)
        rescue Stripe::StripeError => e
        status 402
        return "Error creating subscription: #{e.message}"
    end
    
    begin
       newPlan = Stripe::Plan.retrieve(planP)
        rescue Stripe::StripeError => e
        status 401
        return "Error creating subscription: #{e.message}"
        
    end




    subscription.plan = planP
    subscription.save
    status 200
    
    content_type :json
    return subscription.to_json
    #return
end


post '/customer/cancelPlan' do
    #authenticate!
    # Get the credit card details submitted by the form
    body_parameters = request.body.read
    params.merge!(JSON.parse(body_parameters))
    
    customerP = params[:customer]
    subscriptionP = params[:subscription]
    
    begin
        cu = Stripe::Customer.retrieve(customerP)
        rescue Stripe::StripeError => e
        status 402
        return "Error retrieving customer: #{e.message}"
    end
    begin
        subscription = cu.subscriptions.retrieve(subscriptionP)
        rescue Stripe::InvalidRequestError
        return "Error retrieving subscription charge: #{e.message}"
    end
    
    subscription.delete
    status 200
    
    content_type :json
    return subscription.to_json
    #return
end

post '/customer/sources' do
    #authenticate!
  source = params[:source]

  # Adds the token to the customer's sources
  begin
    @customer.sources.create({:source => source})
  rescue Stripe::StripeError => e
    status 402
    return "Error adding token to customer: #{e.message}"
  end

  status 200
  return "Successfully added source."
end

post '/customer/default_source' do
  authenticate!
  source = params[:source]

  # Sets the customer's default source
  begin
    @customer.default_source = source
    @customer.save
  rescue Stripe::StripeError => e
    status 402
    return "Error selecting default source: #{e.message}"
  end

  status 200
  return "Successfully selected default source."
end

def authenticate!
  # This code simulates "loading the Stripe customer for your current session".
  # Your own logic will likely look very different.
  return @customer if @customer
  if session.has_key?(:customer_id)
    customer_id = session[:customer_id]
    begin
      @customer = Stripe::Customer.retrieve(customer_id)
    rescue Stripe::InvalidRequestError
    end
  else
    begin
      @customer = Stripe::Customer.create(:description => "iOS SDK example customer")
    rescue Stripe::InvalidRequestError
    end
    session[:customer_id] = @customer.id
  end
  @customer
end

# This endpoint is used by the Obj-C example to complete a charge.
post '/charge_card' do
  # Get the credit card details submitted by the form
  token = params[:stripe_token]

  # Create the charge on Stripe's servers - this will charge the user's card
  begin
    charge = Stripe::Charge.create(
      :amount => params[:amount], # this number should be in cents
      :currency => "usd",
      :card => token,
      :description => "Example Charge"
    )
  rescue Stripe::StripeError => e
    status 402
    return "Error creating charge: #{e.message}"
  end

  status 200
  return "Charge successfully created"
end
