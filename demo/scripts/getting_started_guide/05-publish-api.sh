set -x

./04-publish-service.sh
echo "Publishing an API from the OAS definition... as per https://docs.tetrate.io/service-express/getting-started/publish-api"

echo "Define the Application..."

cat <<EOF > bookinfo-app.yaml
apiversion: application.tsb.tetrate.io/v2
kind: Application
metadata:
  organization: tse
  tenant: tse
  name: bookinfo-app
spec:
  displayName: Bookinfo-App
  description: Bookinfo application
  workspace: organizations/tse/tenants/tse/workspaces/bookinfo-ws
  gatewayGroup: organizations/tse/tenants/tse/workspaces/bookinfo-ws/gatewaygroups/bookinfo-gwgroup
EOF

tctl apply -f bookinfo-app.yaml
sleep 10

tctl x status application bookinfo-app --org tse --tenant tse -o yaml

echo "Define the API..."

cat <<'EOF' > bookinfo-api.yaml
apiversion: application.tsb.tetrate.io/v2
kind: API
metadata:
  organization: tse
  tenant: tse
  application: bookinfo-app
  name: bookinfo-api
spec:
  workloadSelector:
    namespace: bookinfo
    labels:
      app: bookinfo-ingress-gw
  openapi: |
    openapi: 3.0.0
    info:
      description: This is the API of the Istio BookInfo sample application.
      version: 1.0.0
      title: BookInfo API
      termsOfService: https://istio.io/
      license:
        name: Apache 2.0
        url: http://www.apache.org/licenses/LICENSE-2.0.html
      x-tsb-service: productpage.bookinfo
    servers:
      - url: http://api.tse.tetratelabs.io/api/v1
    tags:
      - name: product
        description: Information about a product (in this case a book)
      - name: review
        description: Review information for a product
      - name: rating
        description: Rating information for a product
    externalDocs:
      description: Learn more about the Istio BookInfo application
      url: https://istio.io/docs/samples/bookinfo.html
    paths:
      /products:
        get:
          tags:
            - product
          summary: List all products
          description: List all products available in the application with a minimum amount of
            information.
          operationId: getProducts
          responses:
            "200":
              description: successful operation
              content:
                application/json:
                  schema:
                    type: array
                    items:
                      $ref: "#/components/schemas/Product"
      "/products/{id}":
        get:
          tags:
            - product
          summary: Get individual product
          description: Get detailed information about an individual product with the given id.
          operationId: getProduct
          parameters:
            - name: id
              in: path
              description: Product id
              required: true
              schema:
                type: integer
                format: int32
          responses:
            "200":
              description: successful operation
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/ProductDetails"
            "400":
              description: Invalid product id
      "/products/{id}/reviews":
        get:
          tags:
            - review
          summary: Get reviews for a product
          description: Get reviews for a product, including review text and possibly ratings
            information.
          operationId: getProductReviews
          parameters:
            - name: id
              in: path
              description: Product id
              required: true
              schema:
                type: integer
                format: int32
          responses:
            "200":
              description: successful operation
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/ProductReviews"
            "400":
              description: Invalid product id
      "/products/{id}/ratings":
        get:
          tags:
            - rating
          summary: Get ratings for a product
          description: Get ratings for a product, including stars and their color.
          operationId: getProductRatings
          parameters:
            - name: id
              in: path
              description: Product id
              required: true
              schema:
                type: integer
                format: int32
          responses:
            "200":
              description: successful operation
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/ProductRatings"
            "400":
              description: Invalid product id
    components:
      schemas:
        Product:
          type: object
          description: Basic information about a product
          properties:
            id:
              type: integer
              format: int32
              description: Product id
            title:
              type: string
              description: Title of the book
            descriptionHtml:
              type: string
              description: Description of the book - may contain HTML tags
          required:
            - id
            - title
            - descriptionHtml
        ProductDetails:
          type: object
          description: Detailed information about a product
          properties:
            id:
              type: integer
              format: int32
              description: Product id
            publisher:
              type: string
              description: Publisher of the book
            language:
              type: string
              description: Language of the book
            author:
              type: string
              description: Author of the book
            ISBN-10:
              type: string
              description: ISBN-10 of the book
            ISBN-13:
              type: string
              description: ISBN-13 of the book
            year:
              type: integer
              format: int32
              description: Year the book was first published in
            type:
              type: string
              enum:
                - paperback
                - hardcover
              description: Type of the book
            pages:
              type: integer
              format: int32
              description: Number of pages of the book
          required:
            - id
            - publisher
            - language
            - author
            - ISBN-10
            - ISBN-13
            - year
            - type
            - pages
        ProductReviews:
          type: object
          description: Object containing reviews for a product
          properties:
            id:
              type: integer
              format: int32
              description: Product id
            reviews:
              type: array
              description: List of reviews
              items:
                $ref: "#/components/schemas/Review"
          required:
            - id
            - reviews
        Review:
          type: object
          description: Review of a product
          properties:
            reviewer:
              type: string
              description: Name of the reviewer
            text:
              type: string
              description: Review text
            rating:
              $ref: "#/components/schemas/Rating"
          required:
            - reviewer
            - text
        Rating:
          type: object
          description: Rating of a product
          properties:
            stars:
              type: integer
              format: int32
              minimum: 1
              maximum: 5
              description: Number of stars
            color:
              type: string
              enum:
                - red
                - black
              description: Color in which stars should be displayed
          required:
            - stars
            - color
        ProductRatings:
          type: object
          description: Object containing ratings of a product
          properties:
            id:
              type: integer
              format: int32
              description: Product id
            ratings:
              type: object
              description: A hashmap where keys are reviewer names, values are number of stars
              additionalProperties:
                type: string
          required:
            - id
            - ratings
EOF

tctl apply -f bookinfo-api.yaml
sleep 10
tctl x status api bookinfo-api --application bookinfo-app --tenant tse -o yaml

echo "Test the API..."

export GATEWAY_IP=$(kubectl -n bookinfo get service bookinfo-ingress-gw -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")

curl -v http://api.tse.tetratelabs.io/api/v1/products --connect-to "api.tse.tetratelabs.io:80:$GATEWAY_IP"