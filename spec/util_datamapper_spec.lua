local xml
local map

setup(function()
	xml = require "util.xml";
	map = require "util.datamapper";
end);

describe("util.datampper", function()

	local s, x, d
	local disco, disco_info, disco_schema
	setup(function()

		local function attr() return {type = "string"; xml = {attribute = true}} end
		s = {
			type = "object";
			xml = {name = "message"; namespace = "jabber:client"};
			properties = {
				to = attr();
				from = attr();
				type = attr();
				id = attr();
				body = "string";
				lang = {type = "string"; xml = {attribute = true; prefix = "xml"}};
				delay = {
					type = "object";
					xml = {namespace = "urn:xmpp:delay"; name = "delay"};
					properties = {stamp = attr(); from = attr(); reason = {type = "string"; xml = {text = true}}};
				};
				state = {
					type = "string";
					enum = {
						"active",
						"inactive",
						"gone",
						"composing",
						"paused",
					};
					xml = {x_name_is_value = true; namespace = "http://jabber.org/protocol/chatstates"};
				};
				fallback = {
					type = "boolean";
					xml = {x_name_is_value = true; name = "fallback"; namespace = "urn:xmpp:fallback:0"};
				};
				origin_id = {
					type = "string";
					xml = {name = "origin-id"; namespace = "urn:xmpp:sid:0"; x_single_attribute = "id"};
				};
				react = {
					type = "object";
					xml = {namespace = "urn:xmpp:reactions:0"; name = "reactions"};
					properties = {
						to = {type = "string"; xml = {attribute = true; name = "id"}};
						reactions = {type = "array"; items = {type = "string"; xml = {name = "reaction"}}};
					};
				};
			};
		};

		x = xml.parse [[
				<message xmlns="jabber:client" xml:lang="en" to="a@test" from="b@test" type="chat" id="1">
				<body>Hello</body>
				<delay xmlns='urn:xmpp:delay' from='test' stamp='2021-03-07T15:59:08+00:00'>Becasue</delay>
				<UNRELATED xmlns='http://jabber.org/protocol/chatstates'/>
				<active xmlns='http://jabber.org/protocol/chatstates'/>
				<fallback xmlns='urn:xmpp:fallback:0'/>
				<origin-id xmlns='urn:xmpp:sid:0' id='qgkmMdPB'/>
				<reactions id='744f6e18-a57a-11e9-a656-4889e7820c76' xmlns='urn:xmpp:reactions:0'>
					<reaction>👋</reaction>
					<reaction>🐢</reaction>
				</reactions>
				</message>
				]];

		d = {
			to = "a@test";
			from = "b@test";
			type = "chat";
			id = "1";
			lang = "en";
			body = "Hello";
			delay = {from = "test"; stamp = "2021-03-07T15:59:08+00:00"; reason = "Becasue"};
			state = "active";
			fallback = true;
			origin_id = "qgkmMdPB";
			react = {
				to = "744f6e18-a57a-11e9-a656-4889e7820c76";
				reactions = {
					"👋",
					"🐢",
				};
			};
		};

		disco_schema = {
			type = "object";
			xml = {
				name = "iq";
				namespace = "jabber:client"
			};
			properties = {
				to = attr();
				from = attr();
				type = attr();
				id = attr();
				disco = {
					type = "object";
					xml = {
						name = "query";
						namespace	= "http://jabber.org/protocol/disco#info"
					};
					properties = {
						features = {
							type = "array";
							items = {
								type = "string";
								xml = {
									name = "feature";
									x_single_attribute = "var";
								};
							};
						};
					};
				};
			};
		};

		disco_info = xml.parse[[
		<iq type="result" id="disco1" from="example.com">
			<query xmlns="http://jabber.org/protocol/disco#info">
				<feature var="urn:example:feature:1">wrong</feature>
				<feature var="urn:example:feature:2"/>
				<feature var="urn:example:feature:3"/>
				<unrelated var="urn:example:feature:not"/>
			</query>
		</iq>
		]];

		disco = {
			type="result";
			id="disco1";
			from="example.com";
			disco = {
				features = {
					"urn:example:feature:1";
					"urn:example:feature:2";
					"urn:example:feature:3";
				};
			};
		};
	end);

	describe("parse", function()
		it("works", function()
			assert.same(d, map.parse(s, x));
		end);

		it("handles arrays", function ()
			assert.same(disco, map.parse(disco_schema, disco_info));
		end);

	end);

	describe("unparse", function()
		it("works", function()
			local u = map.unparse(s, d);
			assert.equal("message", u.name);
			assert.same(x.attr, u.attr);
			assert.equal(x:get_child_text("body"), u:get_child_text("body"));
			assert.equal(x:get_child_text("delay", "urn:xmpp:delay"), u:get_child_text("delay", "urn:xmpp:delay"));
			assert.same(x:get_child("delay", "urn:xmpp:delay").attr, u:get_child("delay", "urn:xmpp:delay").attr);
			assert.same(x:get_child("origin-id", "urn:xmpp:sid:0").attr, u:get_child("origin-id", "urn:xmpp:sid:0").attr);
			assert.same(x:get_child("reactions", "urn:xmpp:reactions:0").attr, u:get_child("reactions", "urn:xmpp:reactions:0").attr);
			assert.same(2, #u:get_child("reactions", "urn:xmpp:reactions:0").tags);
			for _, tag in ipairs(x.tags) do
				if tag.name ~= "UNRELATED" then
					assert.truthy(u:get_child(tag.name, tag.attr.xmlns) or u:get_child(tag.name), tag:top_tag())
				end
			end
			assert.equal(#x.tags-1, #u.tags)

		end);

		it("handles arrays", function ()
			local u = map.unparse(disco_schema, disco);
			assert.equal("urn:example:feature:1", u:find("{http://jabber.org/protocol/disco#info}query/feature/@var"))
			local n = 0;
			for child in u:get_child("query", "http://jabber.org/protocol/disco#info"):childtags("feature") do
				n = n + 1;
				assert.equal(string.format("urn:example:feature:%d", n), child.attr.var);
			end
		end);

	end);
end)