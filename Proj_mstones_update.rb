# Example to start:
# To test: 
# export juser=
# export jpass=
# curl -u $juser:$jpass https://zendesk.atlassian.net/wiki/rest/api/content/161580589?expand=body.storage | python -mjson.tool
# "PodZilla - After-Party" page ID: 161580589
# EPIC = POD-681
# Command: ruby Proj_mstones_update.rb 247857752 POD-681 aramos

require 'rest-client'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'sanitize'
require "yaml/store"
require_relative 'proj_mstones_lib'


# ================================================================================== MAIN

if ARGV.length != 3
  puts "Wrong num of args - try again."
  exit
end

jirapwd = ENV['jpass']
jirausr = ENV['juser']

if (jirapwd == nil) || (jirausr == nil)
	puts "Usr/pwd to use the Atlassian API is missing!"
	exit
end

confl_pag_ID = ARGV[0]
epic = ARGV[1]
reporter = ARGV[2]

# confluence_url = "https://#{jirausr}:pwd@zendesk.atlassian.net/rest/api/2/issue/" + arg_jira_ticket + "/comment"
confluence_url = "https://#{jirausr}:#{jirapwd}@zendesk.atlassian.net/wiki/rest/api/content/" + confl_pag_ID.to_s + "?expand=body.view"

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
twodarray1,twodarray2 = Hash.new() # to use in the "new rows" usecase.

compare_hashes = Array.new

i = 0 # row
j = 0 # column
key = '0.0'
increment = true

# Process 3rd table of the confluence document & store in a hash
doc.xpath("(//table[@class='wrapped confluenceTable'])[3]//tr").each do |row|
	puts "---ROW---"
	row.xpath('td').each do |cell|
		celltoprint = Sanitize.clean(cell)
		case j 
		when 0 		# epic, milestone_num, descr
			if celltoprint.match(/\^ .+/)
				puts "Skipping this Milestone row."
				puts celltoprint
				increment = false
				break
			else
           		key = i.to_s + "." + "0"
            	twodarray[key] = epic
            	puts "#{key} : " + twodarray[key].to_s
            	key = i.to_s + "." + "1"
            	twodarray[key] = i
            	puts "#{key} : " + twodarray[key].to_s
            	key = i.to_s + "." + "2"
				twodarray[key] = celltoprint
			end
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
				celltoprint = "unassigned"
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
			twodarray[key] = celltoprint.strip
		end
        puts "#{key} : " + twodarray[key]
		j += 1
	end
	if increment # flag not to count rows when skipping rows-milestones
		i += 1
		p i
	end
p i
	increment = true
	j = 0
end

unless i <= 1
	i -= 1 # To remove the initial Milestone Header, not captured as it doesn't have a <td>
end

num_rows_html = i
puts "\n\n### Num rows in the HTML table: " + num_rows_html.to_s

top_key = 0 

if File.file?(ymlfilename)     # If exists this confluence page has been processed before - milestone comparison required
# Update Jiras:
	# Let's start by reading the hash back. Watch out as it has the extra final field - JIRA TICKET
	puts "\n\n### Retrieving file from disk.\n"
	mlst_tables_store.transaction(true) do  # begin read-only transaction, no changes allowed
  		mlst_tables_store.roots.each do |data_read|
    		diskarray[data_read] = mlst_tables_store[data_read]
			r_key = data_read.match(/^\d+/)
			root_key = r_key[0].to_i
			if root_key > top_key.to_i
				top_key = root_key
				# puts "top_key: #{top_key}"
			end
		end
	
  	end

	num_rows_disk = top_key
	puts "Num rows table in DISK: " + num_rows_disk.to_s

	# Let's remove the JIRAs from the Hash so we can compare it later:
	diskarray_nojiras = diskarray.clone
	
	count = 0
	while count < num_rows_disk
		key = count.to_s + ".6"    # 7th element of the rows is the Jira ticket for the Milestone, as per the docum.
		diskarray_nojiras.delete(key)
		count += 1
	end

# Now let's compare hashes to take decisions: Create new Jira_mlstn? update Jira_mlstn? update Pstore in disk?
# http://stackoverflow.com/questions/4928789/how-do-i-compare-two-hashes
	puts "\n### Comparing hashes!\n"
	compare_hashes = twodarray.to_a - diskarray_nojiras.to_a
	p compare_hashes
	stopped_in_row = compare_hashes.flatten.first
	p stopped_in_row

	if twodarray == diskarray                 # Same arrays
		puts "\n### Arrays are the same ==> Nothing to do.\n"
		# No need to create/update Jiras or modify info in Pstore (disk)

	elsif (num_rows_html == num_rows_disk)    # Different arrays but same number of rows ==> same milestone descriptions
		# Edit milestones and Jiras info.
		puts "\n### Different arrays but same number of rows ==> Edit milestones info.\n"
		# Review ALL JIRAs: Get Jira IDs from diskarray and update the modified info from twodarray on them.
		update_jiras_info(twodarray, diskarray, jirausr,jirapwd)   #twodarray now has the jiras (after this call) 

		# Delete diskarray and save the new twodarray in Pstore (less effort)
        ymlfilenameold = ymlfilename + "_old"
        File.rename(ymlfilename,ymlfilenameold)
	    persist_rows(twodarray, ymlfilename)

	else									  # Different arrays and new rows ==> new milestones have appeared + milestones info could have been modified.
		puts "\n### Different arrays and new rows: Add AND/OR update milestones!\n"
		# Edit milestones and Jiras info.
#	split twodarray
		twodarray1 = split_tda(twodarray, num_rows_disk, 1) 
		twodarray2 = split_tda(twodarray, num_rows_disk, 2)
p num_rows_disk
p twodarray1
p twodarray2
		# Step1: Edit milestones and jiras
		update_jiras_info(twodarray1, diskarray, jirausr, jirapwd)    #twodarray1 now has the jiras (after this call)
		# Step2: Add new milestones and Jiras.
		create_jiras(twodarray2, jirausr, jirapwd, epic, num_rows_disk+1, reporter)   # twodarray2 now has the jiras (after this call)

#	merge twodarray
		twodarray = merge_tda(twodarray1,twodarray2)	
		# Delete diskarray and save the new twodarray in Pstore (less effort)
		ymlfilenameold = ymlfilename + "_old"
		File.rename(ymlfilename,ymlfilenameold)
	    persist_rows(twodarray, ymlfilename)
	end

else 
# Create Jiras and persist the data for the 1st time.
	puts "\n\n### Creating Jiras for the 1st time.\n\n"
	create_jiras(twodarray, jirausr, jirapwd, epic, 1, reporter)   # In the OP project, next available Jira issue number, type milestone, and other parameters.

	persist_rows(twodarray, ymlfilename)
end

puts "\nEND."

