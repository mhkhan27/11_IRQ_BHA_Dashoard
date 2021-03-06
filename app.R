rm(list = ls())

# library -----------------------------------------------------------------


library(shiny)
library(shinyWidgets)
library(shinybrowser)
library(leaflet)
library(sf)
library(dplyr)
library(leaflet.extras)
library(htmltools)
library(leafgl)


# read_data ---------------------------------------------------------------

grid <- st_read("01_inputs/01_hexagon/cluster_10_km.shp") %>% st_transform(4326)

###### input from gee
Precipitation <- read.csv("05_outputs/01_precipitation_defict/precipitation_deficit.csv")
NDVI <- read.csv("05_outputs/02_NDVI_Z_value/NDVI_Z_value.csv")
SPI <-  read.csv("05_outputs/01_precipitation_defict/nine_month_spi.csv")
Temperature <- read.csv("05_outputs/04_temperature_Z_value/temperature_Z_value.csv")


##### Admin boundary 
admin_boundary_path <-  "01_inputs/03_admin_boundary/"

admin_zero <-st_read(paste0(admin_boundary_path,"/irq_admbnda_adm0_cso_itos_20190603.shp"))
admin1_boundary  <-st_read(paste0(admin_boundary_path,"/irq_admbnda_adm1_cso_20190603.shp"))
# admin2_boundary  <-st_read(paste0(admin_boundary_path,"/irq_admbnda_adm2_cso_20190603.shp"))
# admin3_boundary  <-st_read(paste0(admin_boundary_path,"/irq_admbnda_adm3_cso_20190603.shp"))




# leaflet base map --------------------------------------------------------

base_map <- leaflet::leaflet() %>% leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron) %>% 
  leaflet::addPolygons(data = admin_zero,color = "#EE5859",fillColor = "transparent") %>% 
  leaflet::addPolygons(data = admin1_boundary,color = "#58585A",
                       #label = ~htmlEscape(ADM1_EN),
                       #labelOptions = labelOptions(noHide = T, textOnly = TRUE,textsize = "15px"),
                       #popup = paste("Governorate:", admin1_boundary$ADM1_EN),
                       weight = 2,dashArray = "12",fillColor = "transparent")

# ui ---------------------------------------------------------------------


ui <- fluidPage(
    
# Styling -----------------------------------------------------------------
    
    tags$head(
      HTML('<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />'), includeCSS("style.css")
    ),
   
    
    navbarPage(
      
      windowTitle = "IRAQ CLIMATE MONITORING DASHBOARD",
      HTML('<a style="padding-left:10px;" class = "navbar-brand" href = "https://www.reach-initiative.org" target="_blank"><img src = "reach_logo.png" height = "50"></a><span class="navbar-text" style="font-size: 16px; color: #FFFFFF"><strong>IRAQ CLIMATE MONITORING DASHBOARD</strong></span>'),
      
  tabPanel("Climate Indicators",
      mainPanel(
        br(),
        h5(strong("Climate change is affecting Iraq very adversely. To help the humanitarian community, REACH has developed this climate monitoring dashboard, so that the implementing agencies can work immediately wherever there is a hotspot")),
        
        hr(),
        
        ##################### input ###############################
        tags$div(pickerInput("select_climate_indicator",
                             label = "Select Climate Indicator:",
                             choices = c("Precipitation","SPI","NDVI","Temperature"),
                             selected = "Precipitation",
                             multiple = F,
                             options = pickerOptions(title = "Select", actionsBox = TRUE, liveSearch = TRUE)
        ),style="display:inline-block"),
        
        tags$div(pickerInput("select_month",
                             label = "Select Month:",
                             choices = NULL,
                             selected = NULL,
                             multiple = F,
                             options = pickerOptions(title = "Select", actionsBox = TRUE, liveSearch = TRUE)
        ),style="display:inline-block"),
        
        actionButton("run", "Show result"), 
        
        
        div(class = "outer", tags$style(type = "text/css", ".outer {position: fixed; top: 200px; left: 0; right: 0; bottom: 0; overflow: hidden; padding: 0}"),
        
            leafglOutput("map",width ="100%", height = "100%"))
        
        
      ) # end main panel  
  ), # tab 1 end 
  
  tabPanel("Global Surface Water",
       mainPanel(

         htmlOutput("frame"),
         em("Source: Joint Research Centre (JRC)"),
       ) # end mainpanel 2   
           
  ) # End table 2
      ) # end navar page
) # end fluid page



# server ------------------------------------------------------------------



server <- function(input, output,session){
  
  indicator <-  reactive({input$select_climate_indicator})
  month_selected <-  reactive({input$select_month})
  
  indicator_df <- reactive({get(indicator())})
  

  
  ####################### available month in name in the selected cilamte indicator ############
  
  available_month <- reactive({indicator_df()$month %>% unique()})
  
  observe({
    updatePickerInput(session, "select_month", choices = available_month())
  })
  
  
  ########################## FILTER AND JOIN ###########################
  df <- eventReactive(input$run,{indicator_df() %>% filter(month == month_selected())})
  
  grid_with_df <- eventReactive(input$run,{grid %>% left_join(df(),by = "FID")})
  
  
  ############################################ MAP #########################################
  

clr <- eventReactive(input$run,{
    if(input$select_climate_indicator %in% c("Precipitation","SPI")) {
    clr <- colorQuantile("RdYlBu", grid_with_df()$value)(grid_with_df()$value)
    return(clr)
      }
    if(input$select_climate_indicator %in%  c("Temperature","NDVI")) {
      clr <- colorQuantile("RdYlGn", grid_with_df()$value)(grid_with_df()$value)
      return(clr)
    }
    
  })
  
  output$map <-  renderLeaflet({
    
    base_map %>%  leafgl::addGlPolygons(data = grid_with_df(),
                                        fillOpacity = 0.7,
                                        color = ~clr(),
                                        stroke = F,
                                        popup = paste("Row_id:", grid_with_df()$FID, "<br>",
                                                      "Parameter:", grid_with_df()$parameter, "<br>",
                                                      "Value:",  grid_with_df()$value)
                                        
    )  %>% setView(lat = 33.312805,lng = 44.361488,zoom = 6) %>% addMiniMap() %>% 
      addSearchOSM()#%>% 
     # addLegend(data = grid_with_df(),pal = clr(), values = ~grid_with_df()$value)

    
    
    # base_map %>%  leaflet::addPolygons(data = grid_with_df(),
    #                                     fillOpacity = 0.5,
    #                                     smoothFactor = 0.5,
    #                                     color = ~clr(),
    #                                     stroke = F,
    #                                     popup = paste("Row_id:", grid_with_df()$FID, "<br>",
    #                                                   "Parameter:", grid_with_df()$parameter, "<br>",
    #                                                   "Value:",  grid_with_df()$value)
    #                                     
    # )  %>% fitBounds(lng1 = 38.78688, 
    #                  lat1 =29.05777, 
    #                  lng2 = 48.63298, 
    #                  lat2 = 37.38891)
    
  })
  
   frame <- tags$iframe(src="https://global-surface-water.appspot.com/map", style="height: 100vh;",scrolling = 'no',width="150%", frameborder = "0")
    
    output$frame <- renderUI({
     frame
      })
}


## App 
shinyApp(ui = ui, server = server)
