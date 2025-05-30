local cjson       = require "cjson"
local helpers     = require "spec.helpers"
local fixtures    = require "spec.03-plugins.16-jwt.fixtures"
local jwt_encoder = require "kong.plugins.jwt.jwt_parser"
local uuid        = require "kong.tools.uuid"


local PAYLOAD = {
  iss = nil,
  nbf = os.time(),
  iat = os.time(),
  exp = os.time() + 3600
}

for _, strategy in helpers.each_strategy() do
  describe("Plugin: jwt (access) [#" .. strategy .. "]", function()
    local jwt_secret
    local jwt_secret_2
    local base64_jwt_secret
    local rsa_jwt_secret_1
    local rsa_jwt_secret_2
    local rsa_jwt_secret_3
    local rsa_jwt_secret_4
    local rsa_jwt_secret_5
    local rsa_jwt_secret_6
    local rsa_jwt_secret_7
    local rsa_jwt_secret_8
    local rsa_jwt_secret_9
    local rsa_jwt_secret_10
    local rsa_jwt_secret_11
    local hs_jwt_secret_1
    local hs_jwt_secret_2
    local proxy_client
    local admin_client
    local nonexisting_anonymous = uuid.uuid() -- a nonexisting consumer id

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy, {
        "routes",
        "services",
        "plugins",
        "consumers",
        "jwt_secrets",
      }, {
        "ctx-checker",
      })

      local routes = {}

      for i = 1, 13 do
        routes[i] = bp.routes:insert {
          hosts = { "jwt" .. i .. ".test" },
        }
      end

      local route_grpc = assert(bp.routes:insert {
        protocols = { "grpc" },
        paths = { "/hello.HelloService/" },
        service = assert(bp.services:insert {
          name = "grpc",
          url = helpers.grpcbin_url,
        }),
      })

      local consumers      = bp.consumers
      local consumer1      = consumers:insert({ username = "jwt_tests_consumer" })
      local consumer2      = consumers:insert({ username = "jwt_tests_base64_consumer" })
      local consumer3      = consumers:insert({ username = "jwt_tests_rsa_consumer_1" })
      local consumer4      = consumers:insert({ username = "jwt_tests_rsa_consumer_2" })
      local consumer5      = consumers:insert({ username = "jwt_tests_rsa_consumer_5" })
      local consumer6      = consumers:insert({ username = "jwt_tests_consumer_6" })
      local consumer7      = consumers:insert({ username = "jwt_tests_hs_consumer_7" })
      local consumer8      = consumers:insert({ username = "jwt_tests_hs_consumer_8" })
      local consumer9      = consumers:insert({ username = "jwt_tests_rsa_consumer_9" })
      local consumer10     = consumers:insert({ username = "jwt_tests_rsa_consumer_10"})
      local consumer11     = consumers:insert({ username = "jwt_tests_rsa_consumer_11"})
      local consumer12     = consumers:insert({ username = "jwt_tests_rsa_consumer_12"})
      local consumer13     = consumers:insert({ username = "jwt_tests_rsa_consumer_13"})
      local consumer14     = consumers:insert({ username = "jwt_tests_rsa_consumer_14"})
      local consumer15     = consumers:insert({ username = "jwt_tests_rsa_consumer_15"})
      local consumer16     = consumers:insert({ username = "jwt_tests_rsa_consumer_16"})
      local anonymous_user = consumers:insert({ username = "no-body" })

      local plugins = bp.plugins

      plugins:insert({
        name     = "jwt",
        route = { id = routes[1].id },
        config   = {},
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[2].id },
        config   = { uri_param_names = { "token", "jwt" } },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[3].id },
        config   = { claims_to_verify = {"nbf", "exp"} },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[4].id },
        config   = { key_claim_name = "aud" },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[5].id },
        config   = { secret_is_base64 = true },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[6].id },
        config   = { anonymous = anonymous_user.id },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[7].id },
        config   = { anonymous = nonexisting_anonymous }, -- a nonexisting consumer id
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[8].id },
        config   = { run_on_preflight = false },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[9].id },
        config   = {
          cookie_names = { "silly", "crumble" },
          realm = "test-jwt"
        },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[10].id },
        config   = { key_claim_name = "kid" },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[11].id },
        config   = { claims_to_verify = {"nbf", "exp"}, maximum_expiration = 300 },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[12].id },
        config   = { header_names = { "CustomAuthorization" } },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = routes[13].id },
        config   = { anonymous = anonymous_user.username },
      })

      plugins:insert({
        name     = "ctx-checker",
        route = { id = routes[1].id },
        config   = { ctx_kind = "kong.ctx.shared",
                     ctx_check_field = "authenticated_jwt_token" },
      })

      plugins:insert({
        name     = "jwt",
        route = { id = route_grpc.id },
        config   = {},
      })

      plugins:insert({
        name     = "ctx-checker",
        route = { id = route_grpc.id },
        config   = { ctx_kind = "kong.ctx.shared",
                     ctx_check_field = "authenticated_jwt_token" },
      })

      jwt_secret        = bp.jwt_secrets:insert { consumer = { id = consumer1.id } }
      jwt_secret_2      = bp.jwt_secrets:insert { consumer = { id = consumer6.id } }
      base64_jwt_secret = bp.jwt_secrets:insert { consumer = { id = consumer2.id } }

      rsa_jwt_secret_1 = bp.jwt_secrets:insert {
        consumer       = { id = consumer3.id },
        algorithm      = "RS256",
        rsa_public_key = fixtures.rs256_public_key
      }

      rsa_jwt_secret_2 = bp.jwt_secrets:insert {
        consumer       = { id = consumer4.id },
        algorithm      = "RS256",
        rsa_public_key = fixtures.rs256_public_key
      }

      rsa_jwt_secret_3 = bp.jwt_secrets:insert {
        consumer       = { id = consumer5.id },
        algorithm      = "RS512",
        rsa_public_key = fixtures.rs512_public_key
      }

      rsa_jwt_secret_4 = bp.jwt_secrets:insert {
        consumer       = { id = consumer9.id },
        algorithm      = "RS384",
        rsa_public_key = fixtures.rs384_public_key
      }

      rsa_jwt_secret_5 = bp.jwt_secrets:insert {
        consumer       = { id = consumer10.id },
        algorithm      = "ES384",
        rsa_public_key = fixtures.es384_public_key
      }

      rsa_jwt_secret_6 = bp.jwt_secrets:insert {
        consumer       = { id = consumer11.id },
        algorithm      = "ES512",
        rsa_public_key = fixtures.es512_public_key
      }

      rsa_jwt_secret_7 = bp.jwt_secrets:insert {
        consumer       = { id = consumer12.id },
        algorithm      = "PS256",
        rsa_public_key = fixtures.ps256_public_key
      }

      rsa_jwt_secret_8 = bp.jwt_secrets:insert {
        consumer       = { id = consumer13.id },
        algorithm      = "PS384",
        rsa_public_key = fixtures.ps384_public_key
      }

      rsa_jwt_secret_9 = bp.jwt_secrets:insert {
        consumer       = { id = consumer14.id },
        algorithm      = "PS512",
        rsa_public_key = fixtures.ps512_public_key
      }

      rsa_jwt_secret_10 = bp.jwt_secrets:insert {
        consumer       = { id = consumer15.id },
        algorithm      = "EdDSA",
        rsa_public_key = fixtures.ed25519_public_key
      }      

      rsa_jwt_secret_11 = bp.jwt_secrets:insert {
        consumer       = { id = consumer16.id },
        algorithm      = "EdDSA",
        rsa_public_key = fixtures.ed448_public_key
      }      

      hs_jwt_secret_1 = bp.jwt_secrets:insert {
        consumer       = { id = consumer7.id },
        algorithm     = "HS384",
        secret        = fixtures.hs384_secret
      }

      hs_jwt_secret_2 = bp.jwt_secrets:insert {
        consumer       = { id = consumer8.id },
        algorithm     = "HS512",
        secret        = fixtures.hs512_secret
      }


      assert(helpers.start_kong {
        database          = strategy,
        plugins           = "bundled, ctx-checker",
        real_ip_header    = "X-Forwarded-For",
        real_ip_recursive = "on",
        trusted_ips       = "0.0.0.0/0, ::/0",
        nginx_conf        = "spec/fixtures/custom_nginx.template",
      })

      proxy_client = helpers.proxy_client()
      admin_client = helpers.admin_client()
    end)

    lazy_teardown(function()
      if proxy_client then
        proxy_client:close()
      end

      if admin_client then
        admin_client:close()
      end

      helpers.stop_kong()
    end)

    describe("refusals", function()
      it("returns 401 Unauthorized if no JWT is found in the request", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt1.test",
          }
        })
        assert.res_status(401, res)
        assert.equal('Bearer', res.headers["WWW-Authenticate"])
      end)
      it("returns 401 if the claims do not contain the key to identify a secret", function()
        PAYLOAD.iss = nil
        local jwt = jwt_encoder.encode(PAYLOAD, "foo")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = assert.res_status(401, res)
        local json = cjson.decode(body)
        assert.same({ message = "No mandatory 'iss' in claims" }, json)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("returns 401 if the claims do not contain a valid key to identify a secret", function()
        PAYLOAD.iss = ""
        local jwt = jwt_encoder.encode(PAYLOAD, "foo")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = assert.res_status(401, res)
        local json = cjson.decode(body)
        assert.same({ message = "Invalid 'iss' in claims" }, json)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("returns 401 Unauthorized if the iss does not match a credential", function()
        PAYLOAD.iss = "123456789"
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = assert.res_status(401, res)
        local json = cjson.decode(body)
        assert.same({ message = "No credentials found for given 'iss'" }, json)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("returns 401 Unauthorized if the signature is invalid", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, "foo")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = assert.res_status(401, res)
        local json = cjson.decode(body)
        assert.same({ message = "Invalid signature" }, json)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("returns 401 Unauthorized if the alg does not match the credential", function()
        local header = {typ = "JWT", alg = 'RS256'}
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret, 'HS256', header)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = assert.res_status(401, res)
        local json = cjson.decode(body)
        assert.same({ message = "Invalid algorithm" }, json)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("returns 200 on OPTIONS requests if run_on_preflight is false", function()
        local res = assert(proxy_client:send {
          method  = "OPTIONS",
          path    = "/request",
          headers = {
            ["Host"] = "jwt8.test"
          }
        })
        assert.res_status(200, res)
      end)
      it("returns Unauthorized on OPTIONS requests if run_on_preflight is true", function()
        local res = assert(proxy_client:send {
          method  = "OPTIONS",
          path    = "/request",
          headers = {
            ["Host"] = "jwt1.test"
          }
        })
        local body = assert.res_status(401, res)
        assert.equal([[{"message":"Unauthorized"}]], body)
        assert.equal('Bearer', res.headers["WWW-Authenticate"])
      end)
      it("returns 401 if the token exceeds the maximum allowed expiration limit", function()
        local payload = {
          iss = jwt_secret.key,
          exp = os.time() + 3600,
          nbf = os.time() - 30
        }
        local jwt = jwt_encoder.encode(payload, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/request/?jwt=" .. jwt,
          headers = {
            ["Host"] = "jwt11.test"
          }
        })
        local body = assert.res_status(401, res)
        assert.equal('{"exp":"exceeds maximum allowed expiration"}', body)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("accepts a JWT token within the maximum allowed expiration limit", function()
        local payload = {
          iss = jwt_secret.key,
          exp = os.time() + 270,
          nbf = os.time() - 30
        }
        local jwt = jwt_encoder.encode(payload, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method = "GET",
          path = "/request/?jwt=" .. jwt,
          headers = {
            ["Host"] = "jwt11.test"
          }
        })
        assert.res_status(200, res)
      end)

      it("rejects gRPC call without credentials", function()
        local ok, err = helpers.proxy_client_grpc(){
          service = "hello.HelloService.SayHello",
          opts = {},
        }
        assert.falsy(ok)
        assert.match("Code: Unauthenticated", err)
      end)

      it("reject if multiple different tokens found", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request?jwt=" .. jwt,
          headers = {
            ["Authorization"] = "Bearer invalid.jwt.token",
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(401, res))
        assert.same({ message = "Multiple tokens provided" }, body)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
    end)

    describe("HS256", function()
      it("proxies the request with token and consumer headers if it was verified", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_consumer", body.headers["x-consumer-username"])
        assert.equal(jwt_secret.key, body.headers["x-credential-identifier"])
        assert.is_nil(body.headers["x-anonymous-consumer"])
      end)

      it("accepts gRPC call with credentials", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local authorization = "Bearer " .. jwt
        local ok, res = helpers.proxy_client_grpc(){
          service = "hello.HelloService.SayHello",
          opts = {
            ["-H"] = ("'Authorization: %s'"):format(authorization),
          },
        }
        assert.truthy(ok)
        assert.same({ reply = "hello noname" }, cjson.decode(res))
      end)

      it("proxies the request if the key is found in headers", function()
        local header = {typ = "JWT", alg = "HS256", kid = jwt_secret_2.key}
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret_2.secret, "HS256", header)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt10.test",
          }
        })
        assert.res_status(200, res)
      end)
      it("proxies the request if secret key is stored in a field other than iss", function()
        PAYLOAD.aud = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt4.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_consumer", body.headers["x-consumer-username"])
        assert.equal(jwt_secret.key, body.headers["x-credential-identifier"])
      end)
      it("proxies the request if secret is base64", function()
        PAYLOAD.iss = base64_jwt_secret.key
        local original_secret = base64_jwt_secret.secret
        local base64_secret = ngx.encode_base64(base64_jwt_secret.secret)
        local res = assert(admin_client:send {
          method  = "PATCH",
          path    = "/consumers/jwt_tests_base64_consumer/jwt/" .. base64_jwt_secret.id,
          body    = {
            key = base64_jwt_secret.key,
            secret = base64_secret},
          headers = {
            ["Content-Type"] = "application/json"
          }
        })
        assert.res_status(200, res)

        local jwt = jwt_encoder.encode(PAYLOAD, original_secret)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt5.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_base64_consumer", body.headers["x-consumer-username"])
        assert.equal(base64_jwt_secret.key, body.headers["x-credential-identifier"])
      end)
      it("returns 200 the JWT is found in the cookie crumble", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt9.test",
            ["Cookie"] = "crumble=" .. jwt .. "; path=/;domain=.jwt9.test",
          }
        })
        assert.res_status(200, res)
      end)
      it("returns 200 if the JWT is found in the cookie silly", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt9.test",
            ["Cookie"] = "silly=" .. jwt .. "; path=/;domain=.jwt9.test",
          }
        })
        assert.res_status(200, res)
      end)
      it("returns 401 if the JWT found in the cookie does not match a credential", function()
        PAYLOAD.iss = "incorrect-issuer"
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt9.test",
            ["Cookie"] = "silly=" .. jwt .. "; path=/;domain=.jwt9.test",
          }
        })
        local body = assert.res_status(401, res)
        local json = cjson.decode(body)
        assert.same({ message = "No credentials found for given 'iss'" }, json)
        assert.equal('Bearer realm="test-jwt", error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("returns a 401 if the JWT in the cookie is corrupted", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = "no-way-this-works" .. jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt9.test",
            ["Cookie"] = "silly=" .. jwt .. "; path=/;domain=.jwt9.test",
          }
        })
        local body = assert.res_status(401, res)
        assert.equal([[{"message":"Bad token; invalid JSON"}]], body)
        assert.equal('Bearer realm="test-jwt", error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("reports a 200 without cookies but with a JWT token in the Authorization header", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt9.test",
            ["Authorization"] = "Bearer " .. jwt,
          }
        })
        assert.res_status(200, res)
      end)
      it("returns 401 if no JWT tokens are found in cookies or Authorization header", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt9.test",
          }
        })
        assert.res_status(401, res)
        assert.equal('Bearer realm="test-jwt"', res.headers["WWW-Authenticate"])
      end)
      it("returns 200 without cookies but with a JWT token in the CustomAuthorization header", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt12.test",
            ["CustomAuthorization"] = "Bearer " .. jwt,
          }
        })
        assert.res_status(200, res)
      end)
      it("finds the JWT in the first header occurrence of a duplicated custom authorization header", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt12.test",
            ["CustomAuthorization"] = {"Bearer " .. jwt, "Bearer other-token"}
          }
        })
        assert.res_status(200, res)
      end)
      it("finds the JWT if given in URL parameters", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request/?jwt=" .. jwt,
          headers = {
            ["Host"] = "jwt1.test",
          }
        })
        assert.res_status(200, res)
      end)
      it("finds the JWT if given in a custom URL parameter", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request/?token=" .. jwt,
          headers = {
            ["Host"] = "jwt2.test",
          }
        })
        assert.res_status(200, res)
      end)
    end)

    describe("RS256", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_1.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs256_private_key, 'RS256')
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_1", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_1.key, body.headers["x-credential-identifier"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_2.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs256_private_key, 'RS256')
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_2", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_2.key, body.headers["x-credential-identifier"])
      end)
      it("proxies the request if conf.secret is base64", function()
        PAYLOAD.iss = rsa_jwt_secret_2.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs256_private_key, 'RS256')
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt5.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_2", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_2.key, body.headers["x-credential-identifier"])
      end)
    end)

    describe("RS512", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_3.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs512_private_key, "RS512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_5", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_3.key, body.headers["x-credential-identifier"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_3.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs512_private_key, "RS512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_5", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_3.key, body.headers["x-credential-identifier"])
      end)
    end)

    describe("RS384", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_4.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs384_private_key, "RS384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_9", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_4.key, body.headers["x-credential-identifier"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_4.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.rs384_private_key, "RS384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_9", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_4.key, body.headers["x-credential-identifier"])
      end)
    end)

    describe("ES512", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_6.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.es512_private_key, "ES512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_11", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_6.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_6.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.es512_private_key, "ES512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_11", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_6.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
    end)

    describe("ES384", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_5.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.es384_private_key, "ES384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_10", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_5.key, body.headers["x-credential-identifier"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_5.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.es384_private_key, "ES384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_10", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_5.key, body.headers["x-credential-identifier"])
      end)
    end)

    describe("PS256", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_7.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ps256_private_key, "PS256")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_12", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_7.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_7.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ps256_private_key, "PS256")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_12", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_7.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
    end)

    describe("PS384", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_8.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ps384_private_key, "PS384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_13", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_8.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_8.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ps384_private_key, "PS384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_13", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_8.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
    end)

    describe("PS512", function()
      it("verifies JWT", function()
        PAYLOAD.iss = rsa_jwt_secret_9.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ps512_private_key, "PS512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_14", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_9.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_9.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ps512_private_key, "PS512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_14", body.headers["x-consumer-username"])
        assert.equal(rsa_jwt_secret_9.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
    end)

    describe("EdDSA", function()
      it("verifies JWT with Ed25519 key", function()
        PAYLOAD.iss = rsa_jwt_secret_10.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ed25519_private_key, "EdDSA")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal(rsa_jwt_secret_10.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
      it("verifies JWT with Ed448 key", function()
        PAYLOAD.iss = rsa_jwt_secret_11.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ed448_private_key, "EdDSA")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal(rsa_jwt_secret_11.key, body.headers["x-credential-identifier"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
      it("identifies Consumer", function()
        PAYLOAD.iss = rsa_jwt_secret_10.key
        local jwt = jwt_encoder.encode(PAYLOAD, fixtures.ed25519_private_key, "EdDSA")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_rsa_consumer_15", body.headers["x-consumer-username"])
        assert.equal(nil, body.headers["x-credential-username"])
      end)
    end)

    describe("HS386", function()
      it("proxies the request with token and consumer headers if it was verified", function()
        PAYLOAD.iss = hs_jwt_secret_1.key
        local jwt = jwt_encoder.encode(PAYLOAD, hs_jwt_secret_1.secret, "HS384")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_hs_consumer_7", body.headers["x-consumer-username"])
        assert.equal(hs_jwt_secret_1.key, body.headers["x-credential-identifier"])
        assert.is_nil(body.headers["x-anonymous-consumer"])
      end)
    end)

    describe("HS512", function()
      it("proxies the request with token and consumer headers if it was verified", function()
        PAYLOAD.iss = hs_jwt_secret_2.key
        local jwt = jwt_encoder.encode(PAYLOAD, hs_jwt_secret_2.secret, "HS512")
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal(authorization, body.headers.authorization)
        assert.equal("jwt_tests_hs_consumer_8", body.headers["x-consumer-username"])
        assert.equal(hs_jwt_secret_2.key, body.headers["x-credential-identifier"])
        assert.is_nil(body.headers["x-anonymous-consumer"])
      end)
    end)

    describe("JWT private claims checks", function()
      it("requires the checked fields to be in the claims", function()
        local payload = {
          iss = jwt_secret.key
        }
        local jwt = jwt_encoder.encode(payload, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request/?jwt=" .. jwt,
          headers = {
            ["Host"] = "jwt3.test"
          }
        })
        local body = cjson.decode(assert.res_status(401, res))
        assert.same({ nbf="must be a number", exp="must be a number" }, body)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("checks if the fields are valid: `exp` claim", function()
        local payload = {
          iss = jwt_secret.key,
          exp = os.time() - 10,
          nbf = os.time() - 10
        }
        local jwt = jwt_encoder.encode(payload, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request/?jwt=" .. jwt,
          headers = {
            ["Host"] = "jwt3.test"
          }
        })
        local body = assert.res_status(401, res)
        assert.equal('{"exp":"token expired"}', body)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
      it("checks if the fields are valid: `nbf` claim", function()
        local payload = {
          iss = jwt_secret.key,
          exp = os.time() + 10,
          nbf = os.time() + 5
        }
        local jwt = jwt_encoder.encode(payload, jwt_secret.secret)
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request/?jwt=" .. jwt,
          headers = {
            ["Host"] = "jwt3.test"
          }
        })
        local body = assert.res_status(401, res)
        assert.equal('{"nbf":"token not valid yet"}', body)
        assert.equal('Bearer error="invalid_token"', res.headers["WWW-Authenticate"])
      end)
    end)

    describe("ctx.authenticated_jwt_token", function()
      it("is added to kong.ctx.shared when authenticated", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt1.test",
          }
        })
        assert.res_status(200, res)
        local header = assert.header("ctx-checker-authenticated-jwt-token", res)
        assert.equal(jwt, header)
      end)
    end)

    describe("config.anonymous", function()
      it("works with right credentials and anonymous", function()
        PAYLOAD.iss = jwt_secret.key
        local jwt = jwt_encoder.encode(PAYLOAD, jwt_secret.secret)
        local authorization = "Bearer " .. jwt
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Authorization"] = authorization,
            ["Host"]          = "jwt6.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal('jwt_tests_consumer', body.headers["x-consumer-username"])
        assert.equal(jwt_secret.key, body.headers["x-credential-identifier"])
        assert.is_nil(body.headers["x-anonymous-consumer"])
      end)
      it("works with wrong credentials and anonymous", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt6.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal('true', body.headers["x-anonymous-consumer"])
        assert.equal('no-body', body.headers["x-consumer-username"])
        assert.equal(nil, body.headers["x-credential-identifier"])
      end)
      it("works with wrong credentials and username in anonymous", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt13.test"
          }
        })
        local body = cjson.decode(assert.res_status(200, res))
        assert.equal('true', body.headers["x-anonymous-consumer"])
        assert.equal('no-body', body.headers["x-consumer-username"])
        assert.equal(nil, body.headers["x-credential-identifier"])
      end)
      it("errors when anonymous user doesn't exist", function()
        local res = assert(proxy_client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "jwt7.test"
          }
        })
        local body = cjson.decode(assert.res_status(500, res))
        assert.same("anonymous consumer " .. nonexisting_anonymous .. " is configured but doesn't exist", body.message)
      end)
    end)
  end)


  describe("Plugin: jwt (access) [#" .. strategy .. "]", function()

    local client
    local user1
    local user2
    local anonymous
    local jwt_token
    local key_auth

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy, {
        "routes",
        "services",
        "plugins",
        "consumers",
        "jwt_secrets",
        "keyauth_credentials",
      })

      local service1 = bp.services:insert({
        path = "/request"
      })

      local route1 = bp.routes:insert {
        hosts     = { "logical-and.test" },
        service   = service1,
      }

      bp.plugins:insert {
        name     = "jwt",
        route = { id = route1.id },
      }

      bp.plugins:insert {
        name     = "key-auth",
        route = { id = route1.id },
      }

      anonymous = bp.consumers:insert {
        username = "Anonymous",
      }

      user1 = bp.consumers:insert {
        username = "Mickey",
      }

      user2 = bp.consumers:insert {
        username = "Aladdin",
      }

      local service2 = bp.services:insert({
        path = "/request"
      })

      local route2 = bp.routes:insert {
        hosts     = { "logical-or.test" },
        service   = service2,
      }

      bp.plugins:insert {
        name     = "jwt",
        route = { id = route2.id },
        config   = {
          anonymous = anonymous.id,
        },
      }

      bp.plugins:insert {
        name     = "key-auth",
        route = { id = route2.id },
        config   = {
          anonymous = anonymous.id,
        },
      }

      key_auth = bp.keyauth_credentials:insert {
        key      = "Mouse",
        consumer = { id = user1.id },
      }

      local jwt_secret = bp.jwt_secrets:insert {
        consumer = { id = user2.id },
      }

      PAYLOAD.iss = jwt_secret.key
      jwt_token   = "Bearer " .. jwt_encoder.encode(PAYLOAD, jwt_secret.secret)

      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
      }))

      client = helpers.proxy_client()
    end)

    lazy_teardown(function()
      if client then
        client:close()
      end

      helpers.stop_kong()
    end)

    describe("multiple auth without anonymous, logical AND", function()

      it("passes with all credentials provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"]          = "logical-and.test",
            ["apikey"]        = "Mouse",
            ["Authorization"] = jwt_token,
          }
        })
        assert.response(res).has.status(200)
        assert.request(res).has.no.header("x-anonymous-consumer")
        local id = assert.request(res).has.header("x-consumer-id")
        local key = assert.request(res).has.header("x-credential-identifier")
        assert.not_equal(id, anonymous.id)
        assert(id == user1.id or id == user2.id)
        assert.equal(key_auth.id, key)
      end)

      it("fails 401, with only the first credential provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"]   = "logical-and.test",
            ["apikey"] = "Mouse",
          }
        })
        assert.response(res).has.status(401)
        assert.equal('Bearer', res.headers["WWW-Authenticate"])
      end)

      it("fails 401, with only the second credential provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "logical-and.test",
            ["Authorization"] = jwt_token,
          }
        })
        assert.response(res).has.status(401)
        assert.equal('Key', res.headers["WWW-Authenticate"])
      end)

      it("fails 401, with no credential provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "logical-and.test",
          }
        })
        assert.response(res).has.status(401)
        assert.equal('Bearer', res.headers["WWW-Authenticate"])
      end)

    end)

    describe("multiple auth with anonymous, logical OR", function()

      it("passes with all credentials provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"]          = "logical-or.test",
            ["apikey"]        = "Mouse",
            ["Authorization"] = jwt_token,
          }
        })
        assert.response(res).has.status(200)
        assert.request(res).has.no.header("x-anonymous-consumer")
        local id = assert.request(res).has.header("x-consumer-id")
        local key = assert.request(res).has.header("x-credential-identifier")
        assert.not_equal(id, anonymous.id)
        assert(id == user1.id or id == user2.id)
        assert.equal(PAYLOAD.iss, key)
      end)

      it("passes with only the first credential provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"]   = "logical-or.test",
            ["apikey"] = "Mouse",
          }
        })
        assert.response(res).has.status(200)
        assert.request(res).has.no.header("x-anonymous-consumer")
        local id = assert.request(res).has.header("x-consumer-id")
        assert.not_equal(id, anonymous.id)
        assert.equal(user1.id, id)
        assert.not_equal(PAYLOAD.iss, res.headers["x-credential-identifier"])
      end)

      it("passes with only the second credential provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"]          = "logical-or.test",
            ["Authorization"] = jwt_token,
          }
        })
        assert.response(res).has.status(200)
        assert.request(res).has.no.header("x-anonymous-consumer")
        local id = assert.request(res).has.header("x-consumer-id")
        local key = assert.request(res).has.header("x-credential-identifier")
        assert.not_equal(id, anonymous.id)
        assert.equal(user2.id, id)
        assert.equal(PAYLOAD.iss, key)
      end)

      it("passes with no credential provided", function()
        local res = assert(client:send {
          method  = "GET",
          path    = "/request",
          headers = {
            ["Host"] = "logical-or.test",
          }
        })
        assert.response(res).has.status(200)
        assert.request(res).has.header("x-anonymous-consumer")
        local id = assert.request(res).has.header("x-consumer-id")
        assert.not_equal(PAYLOAD.iss, res.headers["x-credential-identifier"])
        assert.equal(id, anonymous.id)
      end)
    end)
  end)
end
