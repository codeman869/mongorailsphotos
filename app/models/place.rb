class Place

include ActiveModel::Model

attr_accessor :id, :formatted_address, :location, :address_components

#Class Methods
def self.mongo_client
	Mongoid::Clients.default
end


def self.collection
	self.mongo_client['places']
end

def self.load_all param
	f = param.read
	parsedData = JSON.parse(f)
	self.collection.insert_many(parsedData)
end

def self.find_by_short_name sn

	collection.find({"address_components.short_name": sn})

end

def self.to_places coll
	places = []
	coll.each do |doc| 

		places << Place.new(doc)
	end
	places
end

def self.find id

	result = self.collection.find({:_id=>BSON::ObjectId.from_string(id)}).first
	return result.nil? ? nil : Place.new(result)
end

def self.all(offset=0,limit=nil)

	if limit.nil?
		results = self.collection.find.skip(offset)
	else
		results = self.collection.find.skip(offset).limit(limit)
	end

	self.to_places results

end

def self.get_address_components(sort={},offset=0,limit=nil)

	

	query = [
		{

			

			:$unwind => "$address_components"

			
		},

		{

			:$project => {
				:_id => 1,
				:address_components => 1,
				:formatted_address => 1,
				"geometry.geolocation" => 1
			}
		}
	]

	unless sort.empty?

		query << {

			:$sort => sort
		}

	end


	query << {
		:$skip => offset
	}

	unless limit.nil?

		query << {
			:$limit=> limit
		}

	end


	results = self.collection.aggregate(query)

end


def self.get_country_names

	query = [
		{
			:$unwind => "$address_components"
		},
		{
			:$project => {
				"address_components.types"=>1,
				"address_components.long_name"=>1
			}
		},
		{
			:$match=>{
				"address_components.types"=>"country"
			}
		},
		{
			:$group=>{
				:_id=>"$address_components.long_name"
			}
		}


	]

	results = self.collection.aggregate(query)
	countries = []
	results.each do |doc|

		countries << doc[:_id]
	end

	countries

end

def self.find_ids_by_country_code code
	query = [
		{
			:$match => {

				"address_components.short_name" => code
			}
		},
		{
			:$project => {
				:_id => 1
			}
		}
	]

	results = self.collection.aggregate(query)

	ids = results.map {|doc| doc[:_id].to_s}



end

def self.create_indexes
	self.collection.indexes.create_one({"geometry.geolocation"=>Mongo::Index::GEO2DSPHERE})
end

def self.remove_indexes
	self.collection.indexes.drop_one("geometry.geolocation_2dsphere")
end

def self.near(point, max_meters=0)

	query = {

		"geometry.geolocation" => {

			:$near => point.to_hash
		}

	}

	unless max_meters == 0
		query["geometry.geolocation"]["$maxDistance"] = max_meters
	end


	return self.collection.find(query)

end

#Instance methods

def initialize(params)
	@id = params[:_id].to_s
	@formatted_address = params[:formatted_address]
	@location = Point.new(params[:geometry][:geolocation])
	@address_components = []
	unless params[:address_components].nil?
		params[:address_components].each do |address|

			@address_components << AddressComponent.new(address)
		end
	end


end

def destroy
	self.class.collection.find({:_id=>BSON::ObjectId.from_string(@id)}).delete_one
end

def near(max_meters=0)


	unless max_meters == 0
		results = self.class.near(self.location, max_meters)
	else
		results = self.class.near(self.location)
	end

	return self.class.to_places(results)

end

def photos(offset=0,limit=nil)

	results = Photo.find_photos_for_place @id

	results.skip(offset)

	if !limit.nil?
		results.limit(limit)
	end
	
	photos = []

	results.to_a.map! {|doc|

		photos << Photo.new(doc)
	}

	photos

end

def persisted?
	!@id.nil?
end

end