# defs for Proj_mstones_updt.rb

require 'rest-client'
require 'json'
require 'open-uri'


def persist_rows(tDarray, filename)
	mlst_tables_store = YAML::Store.new(filename)

	mlst_tables_store.transaction do
		tDarray.each do |key, value|
			mlst_tables_store[key] = value
    	end	
	 	mlst_tables_store.commit
	end

end

def cleanowner (txt)
	texto = txt.scan(/\w+/)
	result = "#{texto[0].chars.first}#{texto[1]}"
	return result
end


def create_jiras(tDarray, jirapw)

	jira_url = "https://aramos:#{jirapw}@zendesk.atlassian.net/rest/api/2/issue/"

	# Declaring variables to modify them in the block:
	descr, descr_1stline, owner, eta, milestone = "default"
	
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
	 	when key.match(/[0-9]+.5/)
			milestone = key.match(/([0-9]+).5/)
   	 		status = value
			puts "1.milestone = #{milestone[1]}"
			puts "5.status = #{status}"

			# Let's generate the Jira Title:
			descr_1stline = descr.split("\n")
			if descr_1stline[0] == ' '
				descr_title = descr_1stline[1]	
			else
				descr_title = descr_1stline[0]	
			end
			puts "descr_title = #{descr_title}"
        	
			# Build_json
			jirajson_hash = {:fields => { :project => { :key => "OP" }, :summary => "#{descr_title}", :issuetype => { :name => "Milestone" },
							:assignee => { :name => "#{owner}" }, :reporter => { :name => "amoynihan" }, :duedate => "#{eta}",
							:priority => { :name => "Normal" }, :labels => [ "test_alb", "backlog_grooming" ], :environment => "Test", :description => "#{descr}" }
			}

        	# Send_json. Capture response
			json_msg = JSON.generate(jirajson_hash)
			puts "Sending message...\n\n"
			puts json_msg
			puts "\n"

=begin
			response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
			if(response.code != 201)
   				raise "Error with the http request to create the JIRAs!"
			end
	    	resp_data = JSON.parse(response.body)
=end

# Fake response, so we don't have to create the JIRAs:
			resp_data = '{"id"=>"162738", "key"=>"OP-23948", "self"=>"https://zendesk.atlassian.net/rest/api/2/issue/162738"}'

    		puts "Response:"
    		puts resp_data.to_s

			# Capture the Jira key generated and store it in the array
			jirakey = resp_data.to_s.match(/OP-[^"]+/) 
			puts "\n"
			puts "Jirakey captured: " + jirakey.to_s
			puts "\n"
			if jirakey == ''
				jira_keys << nil
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
       	puts "\n"
       	tDarray.merge!("#{index}" => "#{j}")
		count += 1
	end
	
	return tDarray

=begin
			
        	# Clean_variables

			# Move the issues to the EPIC. This is tested and works
			jira_url = "https://aramos:#{jirapw}@zendesk.atlassian.net/rest/agile/1.0/epic/OP-23028/issue"
			jirajson_hash = {:issues => [ "OP-23089" ]} 
			# Send_json. Capture response
            json_msg = JSON.generate(jirajson_hash)
            puts "Sending message...\n\n"
            puts json_msg
            puts "\n"
            
            response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
=end

end


def update_jiras(tDarray)
	# Description


end

