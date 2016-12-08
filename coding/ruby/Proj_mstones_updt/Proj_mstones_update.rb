# Example to start:
# To test: curl -u aramos:pwd https://zendesk.atlassian.net/wiki/rest/api/content/161580589?expand=body.storage | python -mjson.tool
# "PodZilla - After-Party" page ID: 161580589
# EPIC = POD-681
# Command: ruby Proj_mstones_update.rb 161580589 POD-681

require 'rest-client'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'sanitize'
require "yaml/store"
require_relative 'proj_mstones_lib'


# ================================================================================== MAIN

if ARGV.length != 2
  puts "Wrong num of args - try again."
  exit
end

jirapwd = ENV['jpass']

if (jirapwd == nil)
	puts "Pwd missing to use the Atlassian API!"
	exit
end

confl_pag_ID = ARGV[0]
epic = ARGV[1]

# confluence_url = "https://aramos:pwd@zendesk.atlassian.net/rest/api/2/issue/" + arg_jira_ticket + "/comment"
confluence_url = "https://aramos:#{jirapwd}@zendesk.atlassian.net/wiki/rest/api/content/" + confl_pag_ID.to_s + "?expand=body.view"

response = RestClient.get confluence_url
puts "Response code: ", response.code
if(response.code != 200)
    raise "Error with the http request!"
end

resp_data = JSON.parse(response.body)
puts "### Response ok from confluence page!"
# Getting the html page itself:
atl_layout_html = resp_data["body"]["view"]["value"]
#puts atl_layout_html

# The Nokogiri part:
doc = Nokogiri::HTML(atl_layout_html)

puts"\n\n"
# puts doc

# To persist the info from a serialized Hash: Let's use the class YAML::Store. Docum here: https://robm.me.uk/ruby/2014/01/25/pstore.html
ymlfilename = "#{confl_pag_ID}.yml"
mlst_tables_store = YAML::Store.new(ymlfilename)

# Docum for 2D arrays: http://www.dotnetperls.com/2d-ruby
twodarray = Hash.new() # Hash read from the HTLM table
diskarray = Hash.new() # Hash read from disk
compare_hashes = Array.new
i = 0 # row
j = 0 # column
key = '0.0'

# Process 3rd table of the confluence document & store in a hash
doc.xpath("(//table[@class='wrapped confluenceTable'])[3]//tr").each do |row|
	puts "---ROW---"
	row.xpath('td').each do |cell|
		celltoprint = Sanitize.clean(cell)
		case j 
		when 0 		# epic, milestone_num, descr
			key = i.to_s + "." + "0"
			twodarray[key] = epic
			puts "#{key} : " + twodarray[key].to_s
			key = i.to_s + "." + "1"
			twodarray[key] = i
            puts "#{key} : " + twodarray[key].to_s
            key = i.to_s + "." + "2"
            twodarray[key] = celltoprint
		when 2		# owner
p celltoprint
			tmp = celltoprint.to_s.split("\n")
			celltoprint = nil
p tmp[1]
			tmp.each do |validname|
				if validname.strip.empty?
					puts "-- empty owner."
				else
					celltoprint = cleanowner(validname)
					break
				end
			end
			if celltoprint.nil?
				puts "############################################### No owners matched!!"
				celltoprint = "Unassigned"
			end

			key = i.to_s + "." + "3"
			twodarray[key] = celltoprint
		when 3		# eta, with the right format 
			tmp = celltoprint.to_s.scan(/(\d{4}-\d{2}-\d{2})/)      # Get all the matches.
			if tmp[0]
				celltoprint.replace tmp[-1][0].to_s       # Get the last element of an 2D array
			else
				puts "############################################### No ETA matched (in the expected format)!!"
				celltoprint.replace "1900-01-01"
			end
			key = i.to_s + "." + "4"
			twodarray[key] = celltoprint
		when 4 		# Status
			key = i.to_s + "." + "5"
			twodarray[key] = celltoprint
		end
        puts "#{key} : " + twodarray[key]
		j += 1
	end
	i += 1
	j = 0
end
num_rows_html = i
puts "\n\n### Num rows in the HTML table: " + num_rows_html.to_s

last_key = nil

if File.file?(ymlfilename)     # If exists this confluence page has been processed before - milestone comparison required
# Update Jiras:
	# Let's start by reading the hash back. Watch out as it has the extra final field - JIRA TICKET
	puts "\n\n### Retrieving file from disk.\n"
	mlst_tables_store.transaction(true) do  # begin read-only transaction, no changes allowed
  		mlst_tables_store.roots.each do |data_read|
    		diskarray[data_read] = mlst_tables_store[data_read]
			last_key = data_read
		end
	
  	end

	# Test/show the read is correct:
	puts "Last_key for data in disk: " + last_key

	num_rows_d = last_key.match(/^\d+/)
	num_rows_disk = num_rows_d[0].to_i + 1
	puts "Num rows table in DISK: " + num_rows_disk.to_s

	# Let's remove the JIRAs from the Hash so we can compare it later:
	diskarray_nojiras = diskarray.clone
	
	count = 0
	while count < num_rows_disk
		key = count.to_s + ".6"    # 7th element of the rows is the Jira ticket for the Milestone, as per the docum.
		diskarray_nojiras.delete(key)
		count += 1
	end

	puts "\n\n\n"
	diskarray.each do |key, value|
    	puts key + ' : ' + value.to_s
	end

	# Testing functions
=begin	
	puts "\n\n\n\n\n\n\n"
	test_hash = { "1.0" => "OP-1234", "1.1" => "1", "1.2" => "Implement xyz\n 2-Torpedo", "1.3" => "pmuresan", "1.4" => "2016-12-11", "1.5" => "NOT DONE",
		"2.0" => "OP-1234", "2.1" => "2", "2.2" => "Clean tables 456\n 2- Test and more.\n 3- Third line all good ", "2.3" => "pmuresan", "2.4" => "2016-12-10", "2.5" => "IN PROGRESS",
		"3.0" => "OP-1234", "3.1" => "3", "3.2" => "Build chef scafolding for chef", "3.3" => "dkertesz", "3.4" => "2016-12-07", "3.5" => "NOT DONE" }
	new_hash = create_jiras2(test_hash, jirapwd)

	new_hash.each do |key, value|
        puts key + ' : ' + value
    end
=end	


# Now let's compare hashes to take decisions: Create new Jira_mlstn? update Jira_mlstn? update Pstore in disk?
# http://stackoverflow.com/questions/4928789/how-do-i-compare-two-hashes
	puts "\n### Comparing hashes!\n"
	compare_hashes = twodarray.to_a - diskarray_nojiras.to_a
	p compare_hashes
	stopped_in_row = compare_hashes.flatten.first
	p stopped_in_row

	if twodarray == diskarray               # Same arrays
		puts "\n### Arrays are the same ==> Nothing to do.\n"
		# No need to create/update Jiras or modify info in Pstore (disk)
	elsif (num_rows_html == num_rows_disk)        # Different arrays but same number of rows ==> same milestone descriptions
		# Edit milestones and Jiras info.
		puts "\n### Different arrays but same number of rows ==> Edit milestones info.\n"
		# Review ALL JIRAs: Get Jira IDs from diskarray and update the modified info from twodarray on them.
		update_jiras_info(twodarray, diskarray, jirapwd)

		# Delete diskarray and save the new twodarray in Pstore (less effort)
        ymlfilenameold = ymlfilename + "_old"
        File.rename(ymlfilename,ymlfilenameold)
	    persist_rows(twodarray, ymlfilename)
	else									# Different arrays and new rows ==> new milestones have appeared + milestones info could have been modified.
		puts "\n### Add AND/OR update milestones!\n"
		# Edit milestones and Jiras info.
		update_jiras_info(twodarray, diskarray, jirapwd)
		# Add new milestones and Jiras.
		add_milestones(twodarray, diskarray)
		
		# Delete diskarray and save the new twodarray in Pstore (less effort)
		ymlfilenameold = ymlfilename + "_old"
		File.rename(ymlfilename,ymlfilenameold)
	    persist_rows(twodarray, ymlfilename)
	end

else 
# Create Jiras and persist the data for the 1st time.
	puts "\n\n### Creating Jiras for the 1st time.\n\n"
	create_jiras2(twodarray, jirapwd) # In the OP project, next available Jira issue number, type milestone, and other parameters.

	persist_rows(twodarray, ymlfilename)
end

puts "\nEND."
