db.users.find({partial_following_screen_names: { $all: ["translink", "greenestcity"]}}, {screen_name: -1, _id:0}).forEach(printjson);
