class KosModel {
  final String name;
  final String location;
  final String price;
  final String image;

  final int availableRooms;
  final List<String> facilities;
  final List<String> rules;
  final String description;
  final String address;
  final List<String> images;

  final bool isHidden;

  KosModel({
    required this.name,
    required this.location,
    required this.price,
    required this.image,
    required this.availableRooms,
    required this.facilities,
    required this.rules,
    required this.description,
    required this.address,
    required this.images,
    this.isHidden = false, 
  });
}