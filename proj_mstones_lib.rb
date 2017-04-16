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
	texto = txt.scan(/\S+/)
	result = "#{texto[0].chars.first}#{texto[1]}"
	return result
end


def create_jiras2(tDarray, jirausr, jirapw, epic)
    puts "\n(Function create_jiras2 (empty replacement for create_jiras))\n"

end


def create_jiras(tDarray, jirausr, jirapw, epic_id, start_in_row, reporter)
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
                            :reporter => { :name => "#{reporter}" }, :duedate => "#{eta}",
                            :priority => { :name => "Normal" }, :labels => [ "test_alb", "backlog_grooming" ], :environment => "Test", :description => "#{descr}" }
                }
			else
				jirajson_hash = {:fields => { :project => { :key => "OP" }, :summary => "#{descr_title}", :issuetype => { :name => "Milestone" },
							:assignee => { :name => "#{owner}" }, :reporter => { :name => "#{reporter}" }, :duedate => "#{eta}",
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
			if jirakey == ''
				jira_keys << nil
				puts "Error: No Jira key returned!!"
			else
				jira_keys << jirakey
			end
        	
		end
	end

	# Add the Jirakeys to twoDarray and move the issues to the EPIC (this is tested and works) https://docs.atlassian.com/jira-software/REST/cloud/#agile/1.0/epic-moveIssuesToEpic
    puts "\n### Moving the tickets to the epic.\n"
	count = start_in_row
	jira_keys.each do |jiraid|
		index = count.to_s + ".6"
		puts index
p jira_keys[count-1]
       	puts "\n"
		jira_url = "https://#{jirausr}:#{jirapw}@zendesk.atlassian.net/rest/agile/1.0/epic/#{epic_id}/issue"
		jirajson_hash = {:issues => [ "#{jiraid}" ]}
		# Send_json. Capture response
    	json_msg = JSON.generate(jirajson_hash)
    	puts "Sending API post to move Jira's under an EPIC.\n\n"
    	puts json_msg
    	puts "\n"
           
    	response = RestClient.post jira_url, json_msg, {"Content-Type" => "application/json"}
		if(response.code != 204)
   			raise "Error with the http request to move the JIRAs!"
			p response.code
		end
		# Adding jira_keys to the hash
       	tDarray.merge!("#{index}" => "#{jiraid}")
		count += 1
	end

=begin	
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

# Fake response, so we don't have to create the JIRAs:
        resp_data = '{"id"=>"162738", "key"=>"OP-23948", "self"=>"https://zendesk.atlassian.net/rest/api/2/issue/162738"}'
        puts "Response:"
        puts resp_data.to_s

    end

=end
	
	return tDarray

end


def update_jiras_info(tDarray, dskarray, jirausr, jirapw)
# ETA, Status, Owner are the only fields that can be update as of 29th Jan.
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
			if owner == "unassigned" # https://confluence.atlassian.com/jirakb/how-to-set-assignee-to-unassigned-via-rest-api-in-jira-744721880.html
				owner = "-1"
			end
			eta = tDarray["#{mlst}.4"]
			transition_id = getTransitionID(tDarray["#{mlst}.5"])
p tDarray["#{mlst}.5"]
p transition_id
			# Build_json https://developer.atlassian.com/jiradev/jira-apis/jira-rest-apis/jira-rest-api-tutorials/jira-rest-api-example-edit-issues
			jira_url = "https://#{jirausr}:#{jirapw}@zendesk.atlassian.net/rest/api/2/issue/#{dskarray["#{mlst}.6"]}"
p jira_url
            jirajson_hash = {:fields => {
                                    :assignee => { :name => "#{owner}" },
                                    :duedate => "#{eta}"
                                    }
                            }

            # Send_json. Capture response
            json_msg = JSON.generate(jirajson_hash)
            puts "\nSending JSON message...\n\n"
            puts json_msg
            puts "\n"

           	response = RestClient.put jira_url, json_msg, {"Content-Type" => "application/json"}
            if (response.code != 204)
                raise "Error with the http request to update the JIRA field!"
            end

=begin
# Fake response, so we don't have to create the JIRAs:
            resp_data = '{"id"=>"162738", "key"=>"OP-23948", "self"=>"https://zendesk.atlassian.net/rest/api/2/issue/162738"}'
            puts "Response:"
=end

		end
	end
	
	# Add the Jirakeys from dskArray to twoDarray, so we can persist it with the Jiras.
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


def update_jiras_info2(tDarray, dskarray, jirausr, jirapw)
    puts "\n(Function update_jiras_info2)\n"

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

def split_tda(tDarray, num_rows, part)
	# Splits twodarrays in two pieces, returns the part [part] back.
    puts "\n(Function split_tda)\n"

	tDarray_part = Hash.new()

	if part == 1
		tDarray.each do |key, value|
			mlst_row = key.split('.')
        	mlst = mlst_row[0].to_i
			if mlst <= num_rows
				tDarray_part[key] = value
			end
		end
	elsif part == 2
		tDarray.each do |key, value|
            mlst_row = key.split('.')
            mlst = mlst_row[0].to_i
            if mlst > num_rows
                tDarray_part[key] = value
            end
        end
	else
		puts "Error in param when calling split_tda function."
	end
	return tDarray_part
end


def merge_tda(tDarray1,tDarray2)
	# Merges twodarrays back into one single twodarray
    puts "\n(Function merge_tda)\n"

	tDarray_full = Hash.new()
	
	tDarray_full = tDarray1
	tDarray2.each do |key, value|
		tDarray_full[key] = value
	end
	
	return tDarray_full
end


