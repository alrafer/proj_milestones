# defs for Proj_mstones_updt.rb

require 'rest-client'
require 'json'
require 'open-uri'


def persist_rows(tDarray, filename)
	puts "\n(Function persist_rows)\n"
	mlst_tables_store = YAML::Store.new(filename)
	jiras_flag = 0

	mlst_tables_store.transaction do
		tDarray.each do |key, value|
			mlst_tables_store[key] = value
			if key.match(/[0-9]+.6/)
				jiras_flag = 1
			end
    	end	
	 	mlst_tables_store.commit
	end

	if jiras_flag == 0 
		puts "(Warning: Function persist_rows: No Jiras are stored!)\n"
	end

end


def cleanowner (txt)
	texto = txt.scan(/\w+/)
	result = "#{texto[0].chars.first}#{texto[1]}"
	return result
end


def create_jiras2(tDarray, jirausr, jirapw)
    puts "\n(Function create_jiras2 (empty replacement for create_jiras))\n"

end


def create_jiras(tDarray, jirausr, jirapw)
	puts "\n(Function create_jiras)\n"
	jira_url = "https://#{jirausr}:#{jirapw}@zendesk.atlassian.net/rest/api/2/issue/"

	# Declaring variables to modify them in the block:
	descr, descr_1stline, owner, eta, milestone, transition_id = "default"
	
	# Declare Array to store JIRAs:
	jira_keys = Array.new

	tDarray.each do |key, value|
		case
   	 	when key.match(/[0-9]+.2/)
   	    	descr = value
            puts "2.descr = #{descr}"
   	 	when key.match(/[0-9]+.3/)
   	    	owner = value
            puts "3.owner = #{owner}"
   	 	when key.match(/[0-9]+.4/)
   	    	eta = value
			puts "4.eta = #{eta}"

			# Let's generate the Jira issue summary
			descr_1stline = descr.split("\n")
puts "Descr:"
p descr_1stline
			case descr_1stline[0]
			when  " ", ""
				descr_title = descr_1stline[1].strip
			else
				descr_title = descr_1stline[0].strip
			end
			puts "descr_title = #{descr_title}"
        	
			# Build_json
			case owner
			when "unassigned"
                jirajson_hash = {:fields => { :project => { :key => "OP" }, :summary => "#{descr_title}", :issuetype => { :name => "Milestone" },
                            :reporter => { :name => "aramos" }, :duedate => "#{eta}",
                            :priority => { :name => "Normal" }, :labels => [ "test_alb", "backlog_grooming" ], :environment => "Test", :description => "#{descr}" }
                }
			else
				jirajson_hash = {:fields => { :project => { :key => "OP" }, :summary => "#{descr_title}", :issuetype => { :name => "Milestone" },
							:assignee => { :name => "#{owner}" }, :reporter => { :name => "aramos" }, :duedate => "#{eta}",
							:priority => { :name => "Normal" }, :labels => [ "test_alb", "backlog_grooming" ], :environment => "Test", :description => "#{descr}" }
				}
			end
        	# Send_json. Capture response
			json_msg = JSON.generate(jirajson_hash)
			puts "Sending JSON message...\n\n"
			puts json_msg
			puts "\n"

			response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
			if(response.code != 201)
   				raise "Error with the http request to create the JIRAs!"
			end
	    	resp_data = JSON.parse(response.body)

# Fake response, so we don't have to create the JIRAs:
=begin
			resp_data = '{"id"=>"162738", "key"=>"OP-23948", "self"=>"https://zendesk.atlassian.net/rest/api/2/issue/162738"}'

    		puts "Response:"
    		puts resp_data.to_s
=end

			# Capture the Jira key generated and store it in the array
			jirakey = resp_data.to_s.match(/OP-[^"]+/) 
			puts "\n"
			puts "Jirakey captured: " + jirakey.to_s
			puts "\n"
			if jirakey == ''
				jira_keys << nil
				puts "Error: No Jira key returned!!"
			else
				jira_keys << jirakey
			end
        	
		end
	end

	# Add the Jirakeys to twoDarray
	count = 1
	jira_keys.each do |j|
		index = count.to_s + ".6"
		puts index
p jira_keys[count-1]
       	puts "\n"
       	tDarray.merge!("#{index}" => "#{j}")
		count += 1
	end

	# Update statuses - transitions! :transition => {:id => "#{transition_id}"}. See here: https://answers.atlassian.com/questions/107630/jira-how-to-change-issue-status-via-rest
	# if in status 2 ==> x.
	# if in status 3 ==> x,
	# And more
	jira_keys.each_with_index do |value,j|   # Looping through the milestones to update the status regardless of the order of the tDarray hash
		idx = (j+1).to_s + "." + "5"
puts "Updating status for index #{idx}."
		status = tDarray[idx]
        transition_id = getTransitionID(status)
        puts "5.status = #{status}"
        puts "5.Transition_ID = #{transition_id}"			
	
        idx = (j+1).to_s + "." + "6"
		jirakey = tDarray[idx]
		jira_url = "https://#{jirausr}:#{jirapw}@zendesk.atlassian.net/rest/api/2/issue/#{jirakey}/transitions"
			
		jirajson_hash = { 
						 :update => {
        					 :comment => [
            					{ :add => { :body => "Testing" } }
        					 ] 
						  },
						  :transition => { :id => "#{transition_id}" } 
						}
            
        # Send_json. Capture response
        json_msg = JSON.generate(jirajson_hash)
        puts "\nSending JSON message...\n"
        puts json_msg
        puts "\n"

        response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
        if response.code != 204
            raise "Error with the http request to update the JIRA field (with the transition ID)!"
        end
        # resp_data = JSON.parse(response.body)

# Fake response, so we don't have to create the JIRAs:
=begin
        resp_data = '{"id"=>"162738", "key"=>"OP-23948", "self"=>"https://zendesk.atlassian.net/rest/api/2/issue/162738"}'
        puts "Response:"
        puts resp_data.to_s
=end
    end
	
	return tDarray

=begin
			
        	# Clean_variables?

			# Move the issues to the EPIC. This is tested and works
			jira_url = "https://#{jirausr}:#{jirapw}@zendesk.atlassian.net/rest/agile/1.0/epic/OP-23028/issue"
			jirajson_hash = {:issues => [ "OP-23089" ]} 
			# Send_json. Capture response
            json_msg = JSON.generate(jirajson_hash)
            puts "Sending message...\n\n"
            puts json_msg
            puts "\n"
            
            response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
			if(response.code != 201)
   				raise "Error with the http request to move the JIRAs!"
			end
	    	resp_data = JSON.parse(response.body)
=end

end


def update_jiras_info(tDarray, dskarray, jirausr, jirapw)
	puts "\n(Function update_jiras_info)\n"

	refresh_mlst = Array.new

	dskarray.each do |key, value|   # Generate the list of "dirty" milestones - that we need to refresh
		mlst_row = key.split('.')
		mlst = mlst_row[0].to_i
        if key.match(/[0-9]+\.0/)   # once per milestone. Onwer, ETA, Status
			if ((tDarray["#{mlst}.3"] != dskarray["#{mlst}.3"]) || (tDarray["#{mlst}.4"] != dskarray["#{mlst}.4"]) || (tDarray["#{mlst}.5"] != dskarray["#{mlst}.5"]))
				refresh_mlst[mlst] = "Y"  # refresh the whole milestone (fields 3-5)
			else
	            refresh_mlst[mlst] = "N"  # don't do anything
			end
		end
	end

	puts "\n"
	p refresh_mlst

	refresh_mlst.each_with_index do |value, index|
		if value == "Y"
			mlst = index.to_i
			owner = tDarray["#{mlst}.3"]
			eta = tDarray["#{mlst}.4"]
			transition_id = getTransitionID(tDarray["#{mlst}.5"])
p tDarray["#{mlst}.5"]
p transition_id

			# Build_json https://developer.atlassian.com/jiradev/jira-apis/jira-rest-apis/jira-rest-api-tutorials/jira-rest-api-example-edit-issues
			jira_url = "https://#{jirausr}:#{jirapw}@zendesk.atlassian.net/rest/api/2/issue/#{mlst}.6"
            jirajson_hash = {:fields => {
                                    :assignee => { :name => "#{owner}" },
                                    :duedate => "#{eta}",
                                    :transition => { :id => "#{transition_id}"} }
                            }

            # Send_json. Capture response
            json_msg = JSON.generate(jirajson_hash)
            puts "\nSending JSON message...\n\n"
            puts json_msg
            puts "\n"
=begin
            response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
            if(response.code != 204)
                raise "Error with the http request to update the JIRA field!"
            end
            resp_data = JSON.parse(response.body)
=end
# Fake response, so we don't have to create the JIRAs:
            resp_data = '{"id"=>"162738", "key"=>"OP-23948", "self"=>"https://zendesk.atlassian.net/rest/api/2/issue/162738"}'
            puts "Response:"
            puts resp_data.to_s
		end
	end
	
	# Add the Jirakeys from dskArray to twoDarray
	dskarray.each do |key, value|
		if key.match(/[0-9]+\.6/) 
			mlst_row = key.split('.')
        	mlst = mlst_row[0].to_i
        	tDarray.merge!("#{mlst}.6" => value)
			p key
			p dskarray[key]
		end
    end

	return tDarray
end	


def add_jiras(tDarray, dskarray)
	puts "\n(Function add_jiras)\n"

end


def getTransitionID(status)
	# statuses: "TO DO LATER", "IN PROGRESS", "CLOSED", "RESOLVED"

	puts "\n(Function getTransitionID)\n"

	case status
	when "TO DO LATER"
		return "3"
	when "IN PROGRESS"
		return "821"
	when "CLOSED"
        return "701"
	when "RESOLVED", "DONE"
        return "821"
	end

end
