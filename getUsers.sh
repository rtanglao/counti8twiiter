./getFollowerUserIds.rb $1 2> $1.followers.ids.stderr.txt 
./getUsers100AtaTime.rb # this has to be done every time you call getFollowerUserIds.rb 
./getLocationStartBioCSV.rb $1 > $1-followers-location-created-at-description.csv


