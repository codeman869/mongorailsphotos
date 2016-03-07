class Photo

attr_accessor :id, :location
attr_writer :contents

#Class methods
def self.mongo_client

Mongoid::Clients.default

end

def self.all(offset=0,limit=0)

	if limit == 0
		results = self.mongo_client.database.fs.find.skip(offset).to_a
	else
		results = self.mongo_client.database.fs.find.skip(offset).limit(limit).to_a
	end

	results.map! do |result| 
		result = Photo.new(result)
	end

	results


end

def self.find id
	query = {
		:_id => BSON::ObjectId.from_string(id)
	}

	result = self.mongo_client.database.fs.find(query).first

	result.nil? ? nil : Photo.new(result)

end

def self.find_photos_for_place place

	id = BSON::ObjectId.from_string(place.to_s)

	query = {

		"metadata.place" => id
	}

	results = self.mongo_client.database.fs.find(query)

end

#Instance Methods
def initialize(params={:_id=>nil,:metadata=>{:location=>nil, :place=>nil}})
	@id = params[:_id].nil? ? nil : params[:_id].to_s
	@location = params[:metadata][:location].nil? ? nil : Point.new(params[:metadata][:location])
	@place = params[:metadata][:place].nil? ? nil : params[:metadata][:place]
end

def persisted?
	return !@id.nil?
end

def save
	if !self.persisted?

		gps=EXIFR::JPEG.new(@contents).gps
		@contents.rewind
		@location = Point.new(:lng => gps.longitude, :lat => gps.latitude)

		file = Mongo::Grid::File.new(
			@contents.read, 
				:content_type => "image/jpeg",
				:metadata => {
					:location => @location.to_hash,
					:place => @place.nil? ? "" : BSON::ObjectId.from_string(@place)
				}

		)
		result = self.class.mongo_client.database.fs.insert_one(file)
		@id = result.to_s
	else
		if @place.nil? || @place=="" 
			new_place = ""
		else
			new_place = BSON::ObjectId.from_string(@place)
		end
		
		query = {
			:_id => BSON::ObjectId.from_string(@id)
		}
		self.class.mongo_client.database.fs.find(query).update_one(
			:metadata => {

				:location => @location.to_hash,
				:place => new_place
			}

			)

	end

	
	
end

def contents

	query = {

		:_id => BSON::ObjectId.from_string(@id)
	}

	result = self.class.mongo_client.database.fs.find_one(query).data

end

def destroy

	query = {

		:_id => BSON::ObjectId.from_string(@id)
	}

	file = self.class.mongo_client.database.fs.find_one(query)

	self.class.mongo_client.database.fs.delete_one(file)


end

def find_nearest_place_id(maxDistance)

	place = Place.near(location,maxDistance).limit(1).projection({

		:_id => 1

		}).first[:_id]

end

def place
	return nil if @place.nil? 
	return nil if @place==""
	Place.find @place.to_s
		
end

def place=new_place

	if new_place.is_a?(Place)

		@place = new_place.id.to_s
	else

		@place = new_place.to_s
	end
			

end

end