import React, { useEffect, useState } from 'react'
import tmdbAxiosInstance from '../tmdbAxiosInstance'
import './Row.css'
function Row({title,fetchUrl}) {
const [allMovies,setAllMovies]=useState([])
const [error,setError]=useState(null)
const base_url="https://image.tmdb.org/t/p/original/"

const fetchData=async()=>{
   try {
      const {data}= await tmdbAxiosInstance.get(fetchUrl)
      setAllMovies(Array.isArray(data.results) ? data.results : [])
      setError(null)
   } catch (err) {
      console.error('Failed to fetch TMDB data for', fetchUrl, err)
      setAllMovies([])
      setError('Unable to load movies right now. Please check the API key and network connection.')
   }
}
useEffect(()=>{
    if (fetchUrl) {
      fetchData()
    }
},[fetchUrl])

  return (
    <div className='row'>
        <h1>{title}</h1>
        {error && <div className='row-error'>{error}</div>}
        <div className="all_movies">
            {allMovies.length === 0 && !error && (
                <div className='row-empty'>No movies available.</div>
            )}
            {allMovies.map((item,index)=>(
                <div className='ba' key={item.id || index}>
                   <div className='iim'>
                      <img
                        className='movie'
                        src={item.poster_path ? `${base_url}${item.poster_path}` : ''}
                        alt={item.title || item.name || 'movie poster'}
                      />
                      <div className='back'>
                        <img
                            className='bacimg'
                            src={item.backdrop_path ? `${base_url}${item.backdrop_path}` : ''}
                            alt={item.title || item.name || 'backdrop'}
                        />
                        <div style={{padding: "10px"}}>
                            <div className='butt'>
                                  <button className='watchnow'>Watch now</button>
                                  <button className='plus'>+</button>
                            </div>
                            <h2>{item.original_title || item.title || item.name || 'Untitled'}</h2>
                            <div style={{display:"flex"}}>
                                <h3>{item.release_date ? item.release_date.slice(0,4) : 'N/A'}</h3>
                                <h3> &nbsp;.&nbsp; </h3>
                                <h3>Rating: {item.vote_average ?? 'N/A'}</h3>
                            </div>
                            <p>{item.overview ? item.overview.slice(0,80) : 'No description available.'}</p>
                        </div>
                      </div>
                    </div>
                </div>
            ))}
        </div>

    </div>
  )
}

export default Row