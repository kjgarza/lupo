require 'rails_helper'

RSpec.describe 'Clients', type: :request  do
  let!(:clients)  { create_list(:client, 10) }
  let!(:provider) { create(:provider) }
  let!(:client) { create(:client) }
  let(:params) do
    { "data" => { "type" => "clients",
                  "attributes" => {
                    "uid" => "BL.IMPERIAL",
                    "name" => "Imperial College",
                    "provider_id" => provider.uid,
                    "contact_email" => "bob@example.com" } } }
  end
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' + ENV['JWT_TOKEN']}}

  # Test suite for GET /clients
  describe 'GET /clients' do
    before { get '/clients', headers: headers }

    it 'returns clients' do
      expect(json).not_to be_empty
      expect(json['data'].size).to eq(11)
    end

    it 'returns status code 200' do
      expect(response).to have_http_status(200)
    end
  end

  # Test suite for GET /clients/:id
  describe 'GET /clients/:id' do
    before { get "/clients/#{client.uid}", headers: headers }

    context 'when the record exists' do
      it 'returns the client' do
        expect(json).not_to be_empty
        expect(json.dig('data', 'attributes', 'name')).to eq(client.name)
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'when the record does not exist' do
      before { get "/clients/xxx", headers: headers }

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end

      it 'returns a not found message' do
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The page you are looking for doesn't exist.")
      end
    end
  end

  # Test suite for POST /clients
  describe 'POST /clients' do
    context 'when the request is valid' do
      before { post '/clients', params: params.to_json, headers: headers }
      it 'creates a client' do
        expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College")
      end

      it 'returns status code 201' do
        expect(response).to have_http_status(201)
      end
    end

    context 'when the request is invalid' do
      let(:params) do
        { "data" => { "type" => "clients",
                      "attributes" => {
                        "name" => "Imperial College",
                        "provider_id" => provider.uid,
                        "contact_email" => "bob@example.com" } } }
      end

      before { post '/clients', params: params.to_json, headers: headers }

      it 'returns status code 422' do
        expect(response).to have_http_status(422)
      end

      it 'returns a validation failure message' do
        expect(json["errors"].first).to eq("id"=>"uid", "title"=>"Uid can't be blank")
      end
    end
  end

  # # Test suite for PUT /clients/:id
  describe 'PUT /clients/:id' do
    context 'when the record exists' do
      before { put "/clients/#{client.uid}", params: params.to_json, headers: headers }

      it 'updates the record' do
        expect(json.dig('data', 'attributes', 'name')).to eq("Imperial College")
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end
  end

  # Test suite for DELETE /clients/:id
  describe 'DELETE /clients/:id' do
    before { delete "/clients/#{client.uid}", headers: headers }

    it 'returns status code 204' do
      expect(response).to have_http_status(204)
    end
  end
end
